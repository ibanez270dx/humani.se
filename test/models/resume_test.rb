require "test_helper"

class ResumeTest < ActiveSupport::TestCase
  setup do
    @owner = Admin.create!(email: Admin::OWNER_EMAIL, role: "owner")
  end

  test "publication derives metadata and replaces the singleton atomically" do
    first = publish("resume")
    assert_equal 1, first.id
    assert_equal @owner, first.uploaded_by
    assert_equal first, @owner.uploaded_resume
    assert_equal first.pdf_data.bytesize, first.byte_size
    assert_equal Digest::SHA256.hexdigest(first.pdf_data), first.sha256
    assert_not_includes first.inspect, "%PDF-"
    second = publish("replacement")
    assert_equal 1, Resume.count
    assert_not_equal first.sha256, second.sha256
    assert_equal File.binread(file_fixture("replacement.pdf")), second.pdf_data
    assert_raises(ActiveRecord::InvalidForeignKey){ Admin.transaction(requires_new: true){ @owner.delete } }
  end

  test "invalid files leave the published document unchanged" do
    original = publish("resume").attributes
    ["", "not a PDF", "%PDF-1.4\ntruncated", "x" * (Resume::MAX_BYTES + 1)].each do |bytes|
      assert_raises(ActiveRecord::RecordInvalid){ Resume.publish!(io: StringIO.new(bytes), filename: "resume.pdf", uploaded_by: @owner) }
      assert_equal original, Resume.current.attributes
    end
    %w[zero-pages encrypted malformed].each do |name|
      assert_raises(ActiveRecord::RecordInvalid){ publish(name) }
      assert_equal original, Resume.current.attributes
    end
  end

  test "bootstrap validates the seed and never replaces a published resume" do
    Resume.bootstrap!
    assert_nil Resume.current.uploaded_by
    assert_equal File.binread(Rails.root.join("db/bootstrap/jeff-miller-resume.pdf")), Resume.current.pdf_data
    current = publish("replacement").attributes
    Resume.bootstrap!(path: "missing.pdf")
    assert_equal current, Resume.current.attributes
    Resume.delete_all
    assert_raises(Errno::ENOENT){ Resume.bootstrap!(path: "missing.pdf") }
    assert_raises(ActiveRecord::RecordInvalid){ Resume.bootstrap!(path: file_fixture("malformed.pdf")) }
    assert_nil Resume.current
  end

  test "failed persistence does not partially replace the current document" do
    original = publish("resume").attributes
    deleted = Admin.create!(email: "deleted@example.com")
    deleted.delete
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Resume.transaction(requires_new: true) do
        Resume.publish!(io: StringIO.new(File.binread(file_fixture("replacement.pdf"))), filename: "replacement.pdf", uploaded_by: deleted)
      end
    end
    assert_equal original, Resume.current.attributes
  end

  test "database rejects multiple current rows and mismatched payload sizes" do
    attributes = publish("resume").attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      Resume.transaction(requires_new: true){ Resume.insert_all!([attributes.merge("id" => 2)]) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Resume.transaction(requires_new: true){ Resume.where(id: 1).update_all(byte_size: 0) }
    end
  end

  test "upload reads are bounded and filenames cannot contain paths or control characters" do
    io = StringIO.new("x" * (Resume::MAX_BYTES + 100))
    assert_raises(ActiveRecord::RecordInvalid){ Resume.publish!(io: io, filename: "resume.pdf", uploaded_by: @owner) }
    assert_equal Resume::MAX_BYTES + 1, io.pos
    resume = Resume.publish!(io: StringIO.new(File.binread(file_fixture("resume.pdf"))), filename: "C:\\private\\resume\n.pdf", uploaded_by: @owner)
    assert_equal "resume.pdf", resume.original_filename
  end

  test "publication logs do not include PDF binary literals" do
    output = StringIO.new
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
    publish("resume")
    assert_includes output.string, "SELECT"
    assert_not_includes output.string, File.binread(file_fixture("resume.pdf")).unpack1("H*")
  ensure
    ActiveRecord::Base.logger = previous_logger
  end

  private

  def publish(name)
    File.open(file_fixture("#{name}.pdf"), "rb"){ |file| Resume.publish!(io: file, filename: "#{name}.pdf", uploaded_by: @owner) }
  end
end

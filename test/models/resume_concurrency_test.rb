require "test_helper"

class ResumeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Resume.delete_all
  end

  test "competing initial uploads and bootstrap retain one complete uploaded document" do
    documents = %w[resume replacement].map{ |name| File.binread(file_fixture("#{name}.pdf")) }
    3.times do
      Resume.delete_all
      ready = Queue.new
      start = Queue.new
      threads = [nil, *documents].map do |bytes|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            if bytes
              Resume.publish!(io: StringIO.new(bytes), filename: "resume.pdf", uploaded_by: nil)
            else
              Resume.bootstrap!
            end
          end
        end
      end
      3.times{ ready.pop }
      3.times{ start << true }
      threads.each(&:value)
      assert_equal 1, Resume.count
      current = Resume.current
      assert_includes documents, current.pdf_data
      assert_equal current.pdf_data.bytesize, current.byte_size
      assert_equal Digest::SHA256.hexdigest(current.pdf_data), current.sha256
    end
  end
end

require "stringio"

class Resume < ApplicationRecord
  MAX_BYTES = 5 * 1024 * 1024
  PUBLIC_URL = "https://www.humani.se/resume".freeze
  PUBLIC_FILENAME = "jeff-miller-resume.pdf".freeze
  PUBLICATION_FIELDS = %i[pdf_data byte_size sha256 original_filename uploaded_by_id].freeze

  self.filter_attributes += [:pdf_data]

  belongs_to :uploaded_by, class_name: "Admin", inverse_of: :uploaded_resume, optional: true
  before_validation :derive_metadata
  validates :original_filename, presence: true, length: { maximum: 200 }
  validate :readable_pdf, if: ->{ new_record? || pdf_data_changed? }

  def self.publish!(io:, filename:, uploaded_by:)
    candidate = candidate_from(io, filename: filename, uploaded_by: uploaded_by)
    candidate.validate!
    # Bulk SQL embeds binary literals rather than filtered bind parameters.
    logger.silence do
      upsert(candidate.attributes.except("created_at", "updated_at"), unique_by: :id, update_only: PUBLICATION_FIELDS)
    end
    find(1)
  end

  def self.bootstrap!(path: Rails.root.join("db/bootstrap", PUBLIC_FILENAME))
    return current if exists?(1)

    candidate = File.open(path, "rb"){ |file| candidate_from(file, filename: PUBLIC_FILENAME, uploaded_by: nil) }
    candidate.validate!
    # ON CONFLICT DO NOTHING: a concurrent upload must always win over the seed.
    logger.silence{ insert_all([candidate.attributes.except("created_at", "updated_at")], unique_by: :id) }
    current
  end

  def self.current
    find_by(id: 1)
  end

  def self.candidate_from(io, filename:, uploaded_by:)
    name = File.basename(filename.to_s.tr("\\", "/")).encode("UTF-8", invalid: :replace, undef: :replace, replace: "").gsub(/[[:cntrl:]]/, "").strip
    new(id: 1, pdf_data: io.read(MAX_BYTES + 1), original_filename: name.truncate(200), uploaded_by: uploaded_by)
  end
  private_class_method :candidate_from

  private

  def derive_metadata
    self.id = 1 if new_record?
    self.byte_size = pdf_data&.bytesize || 0
    self.sha256 = Digest::SHA256.hexdigest(pdf_data) if byte_size.between?(1, MAX_BYTES)
  end

  def readable_pdf
    unless byte_size.between?(1, MAX_BYTES)
      errors.add(:base, "Choose a nonempty PDF no larger than 5 MiB.")
      return
    end

    unless pdf_data.start_with?("%PDF-") && pdf_data.rstrip.end_with?("%%EOF")
      errors.add(:base, "Choose a valid PDF file.")
      return
    end

    reader = PDF::Reader.new(StringIO.new(pdf_data))
    if reader.objects.trailer[:Encrypt] || !reader.page_count.positive?
      errors.add(:base, "Choose a PDF with at least one page and no password or encryption.")
      return
    end
    reader.pages.each{ |page| page.walk(Object.new) }
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
    errors.add(:base, "Choose a readable PDF without a password or encryption.")
  end
end

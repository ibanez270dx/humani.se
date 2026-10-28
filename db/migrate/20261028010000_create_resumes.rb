class CreateResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :resumes do |t|
      t.binary :pdf_data, null: false
      t.integer :byte_size, null: false
      t.string :sha256, null: false
      t.string :original_filename, null: false
      t.references :uploaded_by, foreign_key: { to_table: :admins }
      t.timestamps
    end

    add_check_constraint :resumes, "id = 1", name: "resume_singleton"
    add_check_constraint :resumes, "octet_length(pdf_data) BETWEEN 1 AND 5242880 AND byte_size = octet_length(pdf_data)", name: "resume_size"
  end
end

class CsvBidImporter
  attr_reader :count

  def initialize(project, file_contents, params = {}, notify_user = nil)
    require 'csv'
    @count = 0
    @project = project
    @params = params
    @notify_user = notify_user
    @options = {}
    @csv = CSV.parse file_contents.force_encoding('UTF-8'), headers: true

    if !params[:label_imported_bids].blank?
      @options[:label] = @project.labels.where(name: params[:label_imported_bids]).first_or_create(color: "4FEB5A")
    end

    setup_response_fields if params[:override_response_fields] && project.bids.count == 0

    import

    send_user_notification if @notify_user
  end

  def setup_response_fields
    @project.response_fields.destroy_all

    headers = @csv.headers

    if @params[:associate_vendor_account]
      headers.reject! { |k, v| k.downcase.in? ["vendor id", "email"] }
    end

    headers.uniq.each_with_index do |column_name, index|
      @project.response_fields.create(label: column_name, field_type: "paragraph", sort_order: index)
    end
  end

  def import
    @csv.each do |row|
      row = transform_row(row)

      if @params[:associate_vendor_account]
        if row["vendor id"]
          vendor = Vendor.find(row["vendor id"])
        elsif row["email"]
          vendor = Vendor.joins(:user).where(users: { email: row["email"] }).first
        end
      end

      vendor ||= nil

      bid = @project.bids.create(submitted_at: Time.now,
                                 vendor: vendor)

      @project.response_fields.each do |response_field|
        if (val = row[response_field.label.downcase])
          bid.responses.create(response_field_id: response_field.id, value: val)
        end
      end
      if @options[:label]
        bid.labels << @options[:label]
      end

      bid.update_attributes(updated_at: Time.now) # run callbacks now that response_fields are created

      @count += 1
    end
  end

  def transform_row(row)
    transformed = {}

    row.each do |k, v|
      next if v.blank?

      key = k.downcase

      if !transformed.has_key?(key)
        transformed[key] = v
      else
        transformed[key] += ", " + v
      end
    end

    transformed
  end

  def send_user_notification
    @project.create_events(:import_finished, @notify_user, @project)
  end
end

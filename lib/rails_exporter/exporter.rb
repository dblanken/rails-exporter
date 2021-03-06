require "builder"
require "spreadsheet"
require "rubyXL"

require "rubyXL/convenience_methods"

module RailsExporter
  module Exporter
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def export_to_csv(records, context = :default)
        CSV.generate({col_sep: ";", force_quotes: true}) do |csv|
          # HEADER
          csv << get_columns(context).map { |attr|
            attr_name(attr)
          }
          # BODY
          records.each do |record|
            csv << get_values(record, context)
          end
        end
      end

      def export_to_xml(records, context = :default)
        # File XML
        xml = Builder::XmlMarkup.new(indent: 2)
        # Format
        xml.instruct! :xml, encoding: "UTF-8"
        xml.records do
          # Records
          records.each do |record|
            get_values = get_values(record, context)
            xml.record do |r|
              i = 0
              get_columns(context).map do |attr|
                xml.tag!(attr[:column], get_values[i], {title: attr_name(attr)})
                i += 1
              end
            end
          end
        end
      end

      def export_to_xls(records, context = :default)
        # FILE
        file_contents = StringIO.new
        # CHARSET
        Spreadsheet.client_encoding = "UTF-8"
        # NEW document/spreadsheet
        document = Spreadsheet::Workbook.new
        spreadsheet = document.create_worksheet
        spreadsheet.name = I18n.t(:spreadsheet_name, default: ["Spreadsheet"], scope: [:exporters])
        # HEADER FORMAT
        spreadsheet.row(0).default_format = Spreadsheet::Format.new weight: :bold
        # HEADER
        get_columns(context).each_with_index do |attr, i|
          spreadsheet.row(0).insert i, attr_name(attr)
        end
        # ROWS
        records.each_with_index do |record, i|
          values = get_values(record, context)
          spreadsheet.row(i + 1).push(*values)
        end
        # SAVE spreadsheet
        document.write file_contents
        # RETURN STRING
        file_contents.string.force_encoding("binary")
      end

      def export_to_xlsx(records, context = :default)
        # NEW document/spreadsheet
        workbook = RubyXL::Workbook.new
        worksheet = workbook[0]
        # worksheet = workbook.add_worksheet(I18n.t(:spreadsheet_name, default: ['Spreadsheet'], scope: [:exporters]))
        worksheet.sheet_name = I18n.t(:spreadsheet_name, default: ["Spreadsheet"], scope: [:exporters])
        # HEADER FORMAT
        worksheet.change_row_bold(0, true)
        # HEADER (ROW=0)
        get_columns(context).each_with_index do |attr, i|
          worksheet.add_cell(0, i, attr_name(attr))
        end
        # ROWS
        records.each_with_index do |record, row_index|
          values = get_values(record, context)
          values.each_with_index { |value, col_index| worksheet.add_cell(row_index + 1, col_index, value) }
        end
        # RETURN STRING
        workbook.stream.string.force_encoding("binary")
      end

      private

      def get_columns(context)
        send(:columns, context) || []
      end

      def attr_name(attr)
        attr[:label] || attr[:column]
      end

      def get_values(record, context)
        get_columns(context).map do |attribute|
          value = if attribute[:block].nil?
            (begin
               record.send(attribute[:column])
             rescue
               ""
             end)
          else
            attribute[:block].call(record)
          end
          normalize_value(value, attribute[:type])
        end
      end

      def normalize_value(value, type = nil)
        type = type.present? ? type.to_sym : :unknown
        if type == :currency
          ActionController::Base.helpers.number_to_currency(value)
        elsif type == :boolean
          (value == true) || (value == "true") || (value == "1") ? "S" : "N"
        elsif type == :time
          locale_format = I18n.t(:time_format, default: ["%H:%M:%S"], scope: [:exporters])
          (begin
             I18n.l(value, format: locale_format)
           rescue
             value
           end).to_s
        elsif type == :date
          locale_format = I18n.t(:date_format, default: ["%d/%m/%Y"], scope: [:exporters])
          (begin
             I18n.l(value, format: locale_format)
           rescue
             value
           end).to_s
        elsif type == :datetime
          locale_format = I18n.t(:datetime_format, default: ["%d/%m/%Y %H:%M:%S"], scope: [:exporters])
          (begin
             I18n.l(value, format: locale_format)
           rescue
             value
           end).to_s
        else
          (begin
             I18n.l(value)
           rescue
             value
           end).to_s
        end
      end
    end
  end
end

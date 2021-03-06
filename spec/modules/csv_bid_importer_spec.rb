require_relative '../support/no_rails_tests'
require_relative '../../lib/csv_bid_importer'
require 'csv'
require 'active_support/all'

describe CsvBidImporter do

  describe '#initialize' do
    before do
      CsvBidImporter.any_instance.stub(:setup_response_fields)
      CsvBidImporter.any_instance.stub(:import)
    end

    it 'should parse the csv contents' do
      CSV.should_receive(:parse).with("contents", anything)
      importer = CsvBidImporter.new(mock("Project"), "contents", {label_imported_bids: ""})
      importer.instance_variable_get("@options").has_key?(:label).should == false
    end

    it 'should set a label if the param is set' do
      CSV.should_receive(:parse).with("contents", anything)
      importer = CsvBidImporter.new(mock("Project", labels: NoRailsTests::FakeQuery.new), "contents", {label_imported_bids: "yooo"})
      importer.instance_variable_get("@options").has_key?(:label).should == true
    end

    it 'should create response fields only if the option is set' do
      CsvBidImporter.any_instance.should_receive(:setup_response_fields)
      importer = CsvBidImporter.new(mock("Project", bids: []), "contents", {override_response_fields: true}) # yes
      importer = CsvBidImporter.new(mock("Project", bids: []), "contents", {override_response_fields: false}) # no
      importer = CsvBidImporter.new(mock("Project", bids: ["b"]), "contents", {override_response_fields: true}) # no
    end
  end

  describe '#setup_response_fields' do
    before do
      CsvBidImporter.any_instance.stub(:import)
    end

    it 'should destroy the existing response fields' do
      importer = CsvBidImporter.new(project = OpenStruct.new, "contents", {})
      project.should_receive(:response_fields).and_return(response_fields = OpenStruct.new)
      response_fields.should_receive(:destroy_all)
      importer.setup_response_fields
    end

    it 'should create response fields for each unique header' do
      importer = CsvBidImporter.new(project = OpenStruct.new, "contents", {})
      importer.instance_variable_set("@csv", OpenStruct.new(headers: ['a', 'b', 'a', 'vendor id']))
      project.should_receive(:response_fields).at_least(:once).and_return(response_fields = OpenStruct.new)
      response_fields.should_receive(:create).with(hash_including(label: 'a'))
      response_fields.should_receive(:create).with(hash_including(label: 'b'))
      response_fields.should_receive(:create).with(hash_including(label: 'vendor id'))
      importer.setup_response_fields
    end

    it 'should reject "vendor id" or "email" as headers if :associate_vendor_account is true' do
      importer = CsvBidImporter.new(project = OpenStruct.new, "contents", {associate_vendor_account: true})
      importer.instance_variable_set("@csv", OpenStruct.new(headers: ['a', 'vendor id']))
      project.should_receive(:response_fields).at_least(:once).and_return(response_fields = OpenStruct.new)
      response_fields.should_receive(:create).with(hash_including(label: 'a'))
      importer.setup_response_fields
    end
  end

  describe '#import' do
    before do
      CsvBidImporter.any_instance.stub(:setup_response_fields)
      CsvBidImporter.any_instance.stub(:transform_row) do |x| x end
    end

    it 'should transform each row' do
      CSV.stub(:parse).and_return([{a: "b"}, {c: "d"}])
      CsvBidImporter.any_instance.should_receive(:transform_row).exactly(2).times
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {})
    end

    it 'should associate vendors by id' do
      CSV.stub(:parse).and_return([{"vendor id" => 1}])
      stub_const "Vendor", OpenStruct.new
      Vendor.should_receive(:find).with(1)
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {associate_vendor_account: true})
    end

    it 'should associate vendors by email' do
      CSV.stub(:parse).and_return([{"email" => "yo@yo.com"}])
      stub_const "Vendor", NoRailsTests::FakeQuery.new
      Vendor.should_receive(:where).with(users: {email: "yo@yo.com"}).and_return(Vendor)
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {associate_vendor_account: true})
    end

    it 'should create a bid' do
      CSV.stub(:parse).and_return([{"a" => "b"}])
      project = NoRailsTests::FakeQuery.new
      project.should_receive(:create).and_return(bid = NoRailsTests::FakeQuery.new)
      project.should_receive(:response_fields).and_return([])
      importer = CsvBidImporter.new(project, "contents", {})
    end

    it 'should create the correct responses' do
      CSV.stub(:parse).and_return([row = {"a" => "b"}])
      project = NoRailsTests::FakeQuery.new
      project.should_receive(:create).and_return(bid = NoRailsTests::FakeQuery.new)
      project.should_receive(:response_fields).and_return(response_fields = [OpenStruct.new(id: 9, label: "FOO")])
      bid.should_receive(:create).with(hash_including(response_field_id: 9, value: 'hi'))
      row.should_receive(:[]).with("foo").and_return('hi')
      importer = CsvBidImporter.new(project, "contents", {})
    end

    it 'should add the label' do
      CSV.stub(:parse).and_return([{"a" => "b"}])
      project = NoRailsTests::FakeQuery.new
      project.should_receive(:create).and_return(bid = OpenStruct.new(labels: []))
      project.should_receive(:first_or_create).and_return(label = "foo")
      project.should_receive(:response_fields).and_return([])
      bid.should_receive(:update_attributes)
      bid.labels.should_receive(:"<<").with(label)
      importer = CsvBidImporter.new(project, "contents", {label_imported_bids: "foo"})
    end

    it 'should increment the count' do
      CSV.stub(:parse).and_return([{"a" => "b"}])
      project = NoRailsTests::FakeQuery.new
      importer = CsvBidImporter.new(project, "contents", {})
      importer.count.should == 1
    end
  end

  describe '#transform_row' do
    before do
      CsvBidImporter.any_instance.stub(:setup_response_fields)
      CsvBidImporter.any_instance.stub(:import)
    end

    it 'should remove blank values' do
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {})
      importer.transform_row({a: "b", c: ""}).should == {a: "b"}
    end

    it 'should downcase keys' do
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {})
      importer.transform_row({:"A" => "b"}).should == {a: "b"}
    end

    it 'should join identical keys' do
      importer = CsvBidImporter.new(project = NoRailsTests::FakeQuery.new, "contents", {})
      importer.transform_row({"a" => "b", "A" => "c"}).should == {"a" => "b, c"}
    end
  end

end

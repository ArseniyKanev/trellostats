require 'rails_helper'
require 'date'

RSpec.describe ListsController, type: :controller do

  it "checks date transfers from string to Date right" do
    date = "16.02"
    expect(controller.instance_eval { nearest_date(date) } ).to eq Date.strptime(date + ".2015", "%d.%m.%Y")
  end

  it "checks date transfers from string to Date right" do
    date = "13.01"
    expect(controller.instance_eval { nearest_date(date) } ).to eq Date.strptime(date, "%d.%m")
  end

  it "checks date transfers from string to Date right" do
    date = "13.11"
    expect(controller.instance_eval { nearest_date(date) } ).to eq Date.strptime(date + ".2014", "%d.%m.%Y")
  end

end

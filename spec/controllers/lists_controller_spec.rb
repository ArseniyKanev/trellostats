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

  it "checks card name converts to right hash" do
      name = "   trellostat> Карточка с ква[дра]тными скобками и лишними пробелами  (5)  [-/5/.75^]         "
      expect(controller.instance_eval { parse_card_name(name) } ).to eq ({
        hours: "-/5/.75^",
        theme: "Треллостат",
        name: "Карточка с ква[дра]тными скобками и лишними пробелами ",
        spent: 0.0,
        bugfix: 5.0,
        offhour: 0.75,
        estimated: 5.0
      })
    end

    it "checks card name converts to right hash" do
      name = "  theme > Карточка с одним временем   [3]         "
      expect(controller.instance_eval { parse_card_name(name) } ).to eq ({
        hours: "3",
        theme: "UNKNOWN",
        name: "Карточка с одним временем",
        spent: 3.0,
        bugfix: 0,
        offhour: 0,
        estimated: 0
      })
    end

    it "checks card name converts to right hash" do
      name = "Карточка без темы(значка больше) [.5/1^]"
      expect(controller.instance_eval { parse_card_name(name) } ).to eq ({
        hours: ".5/1^",
        theme: "\u2014",
        name: "Карточка без темы(значка больше)",
        spent: 0.5,
        bugfix: 0.0,
        offhour: 1.0,
        estimated: 0
      })
    end

    it "checks card name converts to right hash" do
      name = "Карточка без часов(не должна распарситься)"
      expect(controller.instance_eval { parse_card_name(name) } ).to eq ({
        hours: 0,
        theme: "\u2014",
        name: "Карточка без часов(не должна распарситься)",
        spent: 0,
        bugfix: 0,
        offhour: 0,
        estimated: 0
      })
    end

end

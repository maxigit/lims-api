require 'spec_helper'

require 'lims-api/context_service'
require 'lims-core'
require 'lims-core/persistence/sequel'

require 'integrations/lab_resource_shared'
require 'lims-api/resource_shared'
require 'integrations/spec_helper'

module Lims::Core

  shared_examples_for "updating the order" do
    let(:order_url) { "#{order_uuid}" }
    let(:update_parameters) {  {}.tap do |h|
        h["event"] = event if event
        h["items"] = items if items
        h["state"] = state if state
      end
    }

    let(:order_json) { {
        :status => expected_status,
        :actions => {
          :create => "/orders",
          :update => order_url,
          :read => order_url,
          :delete => order_url
        },
        :items => expected_items,
        :pipeline => expected_pipeline,
        :study => expected_study,
        :creator => expected_creator,
        :state => expected_state,
        :parameters => expected_parameters
      }.tap do |h|

      end
    }
    let(:update_expected_json) {
      update_parameters.merge(:result => order_json, :uuid => order_uuid)
    }
    let(:update_action) { put order_url, update_parameters }
    it "return the correct json" do


      update_action.status.should == 200
      update_action.body.should.match_json update_expected_json

    end

    it "update the object" do
      upate_action # update the order

      body = JSON::parse(update_action.body)
      body[:uuid].should == order_uuid
      body[:order][:actions][:read].should == order_url

      reloaded = get order_url
      reloaded.status.should == 200
      reloaded.body.should.match_json order_json

    end
  end

  shared_examples_for "order saved" do |uuid|
    let!(:order_uuid) {
      store.with_session do |session|
        order_items.each do |role, item|
          order[role] = item
        end
        set_uuid(session, order, uuid)
      end
      uuid
    }
  end
  shared_examples_for "startable" do
    let(:event) { "start" }
    let(:expected_status) { "in_progress" }
    let(:items) {}
    let(:pipeline) {}
    let(:state) {}
    let(:parameters) {}
    let(:creator) {}
    let(:study) {}

    it_behaves_like "updating the order"
  end
  describe Organization::Order do
    include_context "use core context service", :orders
    include_context "JSON"
    let(:model) { "orders" }


    context "#update" do
      include_context "order saved", "11111111-2222-3333-4444-555555555555"
      context "pending order" do
        let(:order) { described_class.new() }
        context "with items" do
          let(:order_items) { { "pending" => Organization::Order::Item.new(:uuid => "pending uuid"),
              "in_progress" => Organization::Order::Item.new(:uuid => "in_progress uuid").tap { |i| i.start! },
              "done" => Organization::Order::Item.new(:uuid => "done uuid").tap { |i| i.complete! }
            }
          }
          it_behaves_like "startable"
          #it_behaves_like "modifiable order"

        end
      end
    end
  end
end


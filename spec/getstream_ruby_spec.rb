require "spec_helper"

RSpec.describe GetStreamRuby do
  before do
    # Clear environment variables
    ENV.delete("STREAM_API_KEY")
    ENV.delete("STREAM_API_SECRET")
    ENV.delete("STREAM_APP_ID")
    GetStreamRuby.instance_variable_set(:@env_client, nil)
    GetStreamRuby.instance_variable_set(:@env_vars_client, nil)
  end

  describe ".manual" do
    it "creates a client with manual configuration" do
      client = GetStreamRuby.manual(
        api_key: "manual_key",
        api_secret: "manual_secret",
        app_id: "manual_app"
      )
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq("manual_key")
      expect(client.configuration.api_secret).to eq("manual_secret")
      expect(client.configuration.app_id).to eq("manual_app")
    end
  end

  describe ".env" do
    it "creates a client with .env file" do
      ENV["STREAM_API_KEY"] = "env_key"
      ENV["STREAM_API_SECRET"] = "env_secret"
      ENV["STREAM_APP_ID"] = "env_app"

      client = GetStreamRuby.env
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq("env_key")
    end
  end

  describe ".env_vars" do
    it "creates a client with environment variables" do
      ENV["STREAM_API_KEY"] = "vars_key"
      ENV["STREAM_API_SECRET"] = "vars_secret"
      ENV["STREAM_APP_ID"] = "vars_app"

      client = GetStreamRuby.env_vars
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq("vars_key")
    end
  end

  describe ".client" do
    it "defaults to .env method" do
      ENV["STREAM_API_KEY"] = "default_key"
      ENV["STREAM_API_SECRET"] = "default_secret"
      ENV["STREAM_APP_ID"] = "default_app"

      client = GetStreamRuby.client
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq("default_key")
    end
  end
end

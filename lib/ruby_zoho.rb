require 'zoho_api'
require 'api_utils'
require 'yaml'
require 'ostruct'

ZOHO_DEFAULT_MODULES = {
  :crm => %w[Accounts Calls Contacts Events Leads Potentials Tasks],
  :recruit => %w[Candidates Clients JobOpenings Events Interviews]
}

module RubyZoho

  class Configuration < OpenStruct
    def services=(services)
      super services
      services.each { |service| self.send("#{service.to_s}=".to_sym, OpenStruct.new)}
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new

    yield(configuration) if block_given?

    configuration.services.each do |service|
      config = self.configuration.send(service)
      config.ignore_fields_with_bad_names ||= true
      config.cache_fields ||= false
      config.cache_path ||= File.join(File.dirname(__FILE__), '..', 'spec', 'fixtures')

      config.enabled_modules = ZOHO_DEFAULT_MODULES[service].concat(
        config.enabled_modules || []
      ).uniq

      config.api = init_api(
        config.api_key,
        config.enabled_modules,
        config.cache_fields,
        config.cache_path,
        config.ignore_fields_with_bad_names
      )
    end

    setup_modules
  end

  def self.init_api(api_key, modules, cache_fields, cache_path, ignore_bad)
    if File.exists?(File.join(cache_path, 'fields.snapshot')) && cache_fields == true
      fields = YAML.load(File.read(File.join(cache_path, 'fields.snapshot')))
      zoho = ZohoApi::Crm.new(api_key, modules, ignore_bad, fields)
    else
      zoho = ZohoApi::Crm.new(api_key, modules, ignore_bad)
      fields = zoho.module_fields
      File.open(File.join(cache_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) } if cache_fields == true
    end

    zoho
  end

  def self.setup_modules
    configuration.services.each do |service|
      service_mod = RubyZoho.const_set(service.to_s.capitalize, Module.new)

      config = self.configuration.send(service)
      config.enabled_modules.each do |module_name|
        klass_name = module_name.chop

        c = Class.new(Base) do
          include RubyZoho
          include ActiveModel
          extend ActiveModel::Naming

          attr_reader :fields
          @module_name = module_name
          @api = config.api
        end

        service_mod.const_set(klass_name, c)
      end
    end
  end

  require 'base'
end

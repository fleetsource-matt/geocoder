require 'geocoder/results/base'

module Geocoder::Result
  class AmazonGeoplaces < Base
    def address
      @data.dig(:address, :label)
    end

    def coordinates
      @coordinates ||= @data[:position].reverse.freeze
    end

    def city
      @data.dig(:address, :locality) || @data.dig(:address, :district)
    end

    def postal_code
      @data.dig(:address, :postal_code)
    end

    def state
      @data.dig(:address, :region, :name)
    end

    def state_code
      @data.dig(:address, :region, :code)
    end

    def province
      @data.dig(:address, :subregion, :name) || super
    end

    def province_code
      @data.dig(:address, :subregion, :code) || super
    end

    def country
      @data.dig(:address, :country, :name)
    end

    def country_code
      @data.dig(:address, :country, :code_2)
    end
  end
end

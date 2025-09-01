require 'geocoder/lookups/base'
require 'geocoder/results/amazon_geoplaces'

module Geocoder::Lookup
  # A lookup that uses the Amazon GeoPlaces API.
  # You'll need to install the `aws-sdk-geoplaces` gem.
  # See https://docs.aws.amazon.com/location/latest/developerguide/places.html
  #
  class AmazonGeoplaces < Base
    # These are optional query parameters for forward geocoding, which may be
    # set in the configuration file or passed in with the query
    GEOCODE_OPTIONS = %i[
      max_results bias_position filter additional_features language
      political_view intended_use key
    ].freeze

    # These are optional query parameters for reverse geocoding, which may be
    # set in the configuration file or passed in with the query
    REVERSE_OPTIONS = %i[
      query_radius max_results filter additional_features language
      political_view intended_use key
    ].freeze

    def results(query)
      params = build_parameters(query,  configuration)
      fetch_data(query, params)
    end

    # Build the query request from configuration defaults and options provided
    # to the lookup call. The returned hash contains only the parameters that
    # will influence the result. Non-influencing parameters are stored in member
    # variables.
    def build_parameters(query, config)
      permitted_options = query.reverse_geocode? ? REVERSE_OPTIONS : GEOCODE_OPTIONS

      # Check the config option "api_key" for an API key, as that's what the
      # other lookups use. It'll get overridden by the "key" option if that's
      # also set.
      parameters = { key: config[:api_key] }
        .merge(config)
        .merge(query.options)
        .slice(*permitted_options)
        .compact

      # Set the actual query
      if query.reverse_geocode?
        parameters[:query_position] = query.coordinates.reverse.map(&:to_f)
      else
        parameters[:query_text] = query.sanitized_text
      end

      # Remove elements that don't influence the cache key
      @store = parameters.delete(:intended_use) == "Storage"
      @key = parameters.delete(:key)

      parameters
    end

    # A key that uniquely identifies the request. This is used to cache the
    # results of the request if storage is allowed
    def cache_key(params)
      "amzn://geoplaces?#{hash_to_query(params)}"
    end

    # Fetch data from cache or make a request to the Amazon Geoplaces API
    # and cache the result if storage is allowed. Returns an array of hashes
    def fetch_data(query, params)
      key = cache_key(params)

      if cached_result = cache&.public_send(:[], key)
        @cache_hit = true
        JSON.parse(cached_result, symbolize_names: true)
      else
        @cache_hit = false
        result = call_geoplaces_api(query, params)
        encache_result(key, result)
        result
      end
    end

    # Call out to the AWS Geoplaces API and return the result as an array of
    # place hashes
    def call_geoplaces_api(query, params)
      method = query.reverse_geocode? ? :reverse_geocode : :geocode
      params[:key] = @key if @key
      params[:intended_use] = @store ? "Storage" : "SingleUse"
      client.public_send(method, params)
        .to_h
        .fetch(:result_items, nil)
    rescue Aws::GeoPlaces::Errors::ServiceError => e
      raise_error(e) ||
        Geocoder.log(:warn, "AWS GeoPlaces API error: #{e.message}")
      nil
    end

    # Add the result to the cache if caching is enabled, the result is valid
    # and we have indicated in the API call that we want to cache the result
    # (i.e. the intended_use is set to "Storage")
    def encache_result(key, result)
      return unless @store && result && cache

      cache[key] = JSON.generate(result)
    end

    def client
      @client ||= begin
        require_sdk
        opts = client_options(configuration)
        client_class.new(**opts)
      end
    end

    # A hack to allow stubbing the client in tests
    def client_class
      Aws::GeoPlaces::Client
    end

    def require_sdk
      begin
        require 'aws-sdk-geoplaces'
      rescue LoadError
        msg = "Couldn't load the Amazon Geoplaces SDK. " \
              "Install it with: gem install aws-sdk-geoplaces'"
        raise_error(Geocoder::ConfigurationError, msg) ||
          Geocoder.log(:error, msg)
      end
    end

    # Extract client region and credentials from the configuration hash
    def client_options(config)
      region = config[:region]
      credentials = config[:credentials]
      credentials = if credentials.respond_to?(:call)
                      credentials.call
                    elsif credentials.is_a?(Hash)
                      Aws::Credentials.new(
                        credentials[:access_key_id],
                        credentials[:secret_access_key]
                      )
                    end
      { region:, credentials: }.compact
    end
  end
end

require "test_helper"

class AmazonGeoplacesTest < GeocoderTestCase
  %i[constructed_with method_called called_with respond_with].each do |delegated|
    define_method("api_client_#{delegated}") do
      Geocoder::Lookup::MockAmazonGeoplacesClient.send(delegated)
    end
  end

  def setup
    super
    Geocoder::Lookup.reconfigure!
  end

  FORWARD_QUERY = "Madison Square Garden, New York, NY"
  REVERSE_QUERY = [45.423733, -75.676333]

  FORWARD_OPTIONS = {
    max_results: 10,
    bias_position: [45.423733, -75.676333],
    filter: { include_countries: ["US", "CA"] },
    additional_features: ["TimeZone"],
    language: "en",
    political_view: "US",
    intended_use: "Storage",
    key: "key",
    invalid_option: "invalid_option"
  }

  REVERSE_OPTIONS = {
    query_radius: 1000,
    max_results: 10,
    filter: { include_countries: ["US", "CA"] },
    additional_features: ["TimeZone"],
    language: "en",
    political_view: "US",
    intended_use: "Storage",
    key: "key",
    invalid_option: "invalid_option"
  }


  def test_it_uses_region_and_credentials_from_config
    Geocoder.configure(
      lookup: :amazon_geoplaces,
      amazon_geoplaces: {
        region: "us-east-1",
        credentials: {
          access_key_id: "access_key_id",
          secret_access_key: "secret_access_key"
        }
      }
    )
    Geocoder.search(FORWARD_QUERY)

    assert_equal "us-east-1", api_client_constructed_with[:region]
    assert_equal "access_key_id", api_client_constructed_with[:credentials].access_key_id
    assert_equal "secret_access_key", api_client_constructed_with[:credentials].secret_access_key
  end

  def test_it_allows_credentials_to_be_a_callable
    dummy_credentials = Object.new
    Geocoder.configure(
      lookup: :amazon_geoplaces,
      amazon_geoplaces: {
        credentials: -> { dummy_credentials}
      }
    )
    Geocoder.search(FORWARD_QUERY)

    assert_equal dummy_credentials, api_client_constructed_with[:credentials]
  end


  def test_it_gets_default_forward_query_options_from_config
    Geocoder.configure(lookup: :amazon_geoplaces, amazon_geoplaces: FORWARD_OPTIONS)
    expected_args = FORWARD_OPTIONS.except(:invalid_option).merge(query_text: FORWARD_QUERY)
    Geocoder.search(FORWARD_QUERY)

    assert_equal expected_args, api_client_called_with
  end

  def test_it_gets_default_reverse_query_options_from_config
    Geocoder.configure(lookup: :amazon_geoplaces, amazon_geoplaces: REVERSE_OPTIONS)
    expected_args = REVERSE_OPTIONS.except(:invalid_option)
      .merge(query_position: [-75.676333, 45.423733])
    Geocoder.search(REVERSE_QUERY)

    assert_equal expected_args, api_client_called_with
  end

  def test_it_informs_aws_and_caches_results_if_store_flag_is_set
    Geocoder.configure(cache: {}, lookup: :amazon_geoplaces)
    result1 = Geocoder.search(FORWARD_QUERY, intended_use: "Storage", max_results: 10)
    expected_args = { query_text: FORWARD_QUERY, max_results: 10, language: :en, intended_use: "Storage" }

    assert_equal expected_args, api_client_called_with
    assert !result1.first.cache_hit

    result2 = Geocoder.search(FORWARD_QUERY, max_results: 10)

    assert result2.first.cache_hit
  end

  def test_it_does_not_cache_if_store_flag_is_not_set
    Geocoder.configure(cache: {}, lookup: :amazon_geoplaces)
    result1 = Geocoder.search(FORWARD_QUERY, max_results: 10)
    result2 = Geocoder.search(FORWARD_QUERY, max_results: 10)

    assert !result1.first.cache_hit
    assert !result2.first.cache_hit
  end
end

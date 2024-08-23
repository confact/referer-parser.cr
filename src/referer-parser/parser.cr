require "uri"
require "yaml"

module RefererParser
  class Parser
    getter :name_hash
    getter :domain_index

    DefaultFile = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "referers.yml"))

    # Create a new parser from one or more filenames/uris, defaults to ../../data/referers.yml
    def initialize(@file_path : String = DefaultFile, get_data : Bool = true)
      @domain_index = {} of String => Array(Array(String))
      @name_hash = {} of String => NamedTuple(source: String, medium: String, parameters: Array(String) | Nil)

      deserialize_referer_data if get_data
    end

    # Clean out the database
    def clear!
      @domain_index = {} of String => Array(Array(String))
      @name_hash = {} of String => NamedTuple(source: String, medium: String, parameters: Array(String) | Nil)
      true
    end

    def parse(obj : String | URI)
      url = obj.is_a?(URI) ? obj : URI.parse(obj)

      data = {
        known:  false,
        uri:    url.to_s,
        domain: nil,
        term:   nil,
        source: nil,
      }

      domain, name_key = domain_and_name_key_for(url)
      return data unless domain && name_key

      referer_data = @name_hash[name_key]
      term = extract_term(url, referer_data[:parameters])

      {
        known:  true,
        source: referer_data[:source],
        medium: referer_data[:medium],
        uri:    url.to_s,
        domain: domain,
        term:   term,
      }
    end

    # Add a referer to the database with medium, name, domain or array of domains, and a parameter or array of parameters
    # If called manually and a domain is added to an existing entry with a path, you may need to call optimize_index! afterwards.
    def add_referer(medium, name, domains, parameters = [""])
      # The same name can be used with multiple mediums so we make a key here
      name_key = "#{name}-#{medium}"

      # Update the name has with the parameter and medium data
      @name_hash[name_key] = {source: name, medium: medium, parameters: parameters}

      # Update the domain to name index
      domains.each do |domain_url|
        if domain_url.is_a?(YAML::Any)
          domain_url = domain_url.as_s
        end

        # Use URI to parse the domain and path
        uri = URI.parse("http://#{domain_url}")
        domain = uri.host.not_nil!.downcase.sub(/\Awww\./, "")
        path = uri.path.empty? ? "/" : uri.path

        @domain_index[domain] ||= [] of Array(String)
        @domain_index[domain] << [path, name_key]
      end
    end

    # Prune duplicate entries and sort with the most specific path first if there is more than one entry
    # In this case, sorting by the longest string works fine
    def optimize_index!
      @domain_index.each_key do |key|
        # Remove duplicates and sort by longest path first
        @domain_index[key].uniq!.sort! { |a, b| b[0].size <=> a[0].size }
      end
    end

    def deserialize_referer_data
      parse_referer_data(deserialize_yaml(File.read(@file_path)))
      optimize_index!
    end

    protected def deserialize_yaml(data)
      YAML.parse(data)
    rescue Exception
      raise "Unable to YAML file"
    end

    protected def parse_referer_data(data)
      data.as_h.each do |medium, name_hash|
        name_hash.as_h.each do |name, name_data|
          add_referer(medium.as_s, name.as_s, name_data["domains"].as_a, name_data["parameters"]?.try { |p| p.as_a.map { |par| par.as_s } })
        end
      end
    end

    protected def extract_term(url : URI, parameters : Array(String)?)
      return nil unless parameters && url.query

      query_params = url.query_params
      parameters.each do |param|
        term = query_params.fetch_all(param).find { |v| !v.strip.empty? }
        return term if term
      end

      nil
    end

    protected def domain_and_name_key_for(uri)
      host = uri.host.not_nil!.downcase

      # Try direct match with or without 'www.'
      simplified_host = host.sub(/\Awww\./, "")
      [host, simplified_host].each do |domain|
        result = get_domain(uri, domain)
        return result if result
      end

      # Remove subdomains until only two parts remain
      host_parts = simplified_host.split(".")
      while host_parts.size > 2
        host_parts.shift
        result = get_domain(uri, host_parts.join("."))
        return result if result
      end

      [nil, nil]
    end

    protected def get_domain(uri, domain : String)
      domain_downcase = domain.downcase
      uri_path = uri.path.empty? ? "/" : uri.path

      if paths = @domain_index[domain_downcase]?
        paths.each do |path|
          return [domain_downcase, path[1]] if uri_path.includes?(path.first)
        end
      end

      nil
    end
  end
end

require "uri"
require "yaml"

module RefererParser
  class Parser
    getter :name_hash
    getter :domain_index

    DefaultFile = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "referers.yml"))

    # Create a new parser from one or more filenames/uris, defaults to ../data/referers.json
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

    # Given a string or URI, return a hash of data
    def parse(obj : String | URI)
      url = obj.is_a?(URI) ? obj : URI.parse(obj)

      data = {known: false, uri: url.to_s, domain: nil, term: nil, source: nil}

      domain, name_key = domain_and_name_key_for(url)

      return data unless domain && name_key

      referer_data = @name_hash[name_key]
      term = nil
      # Parse parameters if the referer uses them
      if url.query && referer_data[:parameters]
        query_params = url.query_params
        (referer_data[:parameters]? || [""]).each do |param|
          # If there is a matching parameter, get the first non-blank value
          unless (values = query_params.fetch_all(param)).empty?
            term = values.reject { |v| v.strip.empty? }
            term = term.empty? ? nil : term.first
            break if term
          end
        end
      end

      return {
        known:  true,
        source: referer_data[:source],
        medium: referer_data[:medium],
        uri:    url.to_s,
        term:   term,
        domain: domain,
      }
    end

    protected def domain_and_name_key_for(uri)
      # Create a proc that will return immediately
      if !uri.host.nil?
        if uri.host =~ /\Awww\.(.+)\z/i
          match = /\Awww\.(.+)\z/i.match(uri.host.not_nil!)
          returned = get_domain(uri, match[1]) unless match.nil?
          return returned unless returned.nil?
        else
          returned = get_domain(uri, uri.host.not_nil!)
          return returned unless returned.nil?
        end
      end

      # Remove subdomains until only three are left (probably good enough)
      if !uri.host.nil?
        host_arr = uri.host.not_nil!.split(".")
        while host_arr.size > 2
          host_arr.shift
          returned = get_domain(uri, host_arr.join("."))
          return returned unless returned.nil?
        end
      end

      [nil, nil]
    end

    protected def get_domain(uri, domain : String)
      domain2 = domain.downcase
      uri_path = if uri.path.empty?
        "/"
      else
        uri.path
      end
      if paths = @domain_index[domain2]
        paths.each do |path|
          return [domain2, path[1]] if uri_path.includes?(path.first)
        end
      end
    rescue KeyError
      nil
    end

    # Add a referer to the database with medium, name, domain or array of domains, and a parameter or array of parameters
    # If called manually and a domain is added to an existing entry with a path, you may need to call optimize_index! afterwards.
    def add_referer(medium, name, domains, parameters = [""])
      # The same name can be used with multiple mediums so we make a key here
      name_key = "#{name}-#{medium}"

      # Update the name has with the parameter and medium data
      @name_hash[name_key] = {source: name, medium: medium, parameters: parameters}

      # Update the domain to name index
      [domains].flatten.each do |domain_url|
        if domain_url.is_a?(YAML::Any)
          domain_url = domain_url.as_s
        end
        domains = domain_url.split("/", 2)
        domain = domains.first
        path = domains[1]?
        match = /\Awww\.(.*)\z/i.match(domain)
        domain = match[1] if !match.nil?

        domain = domain.downcase

        path = (path || "").split("/")

        @domain_index[domain] ||= [] of Array(String)
        @domain_index[domain] << if !path.empty?
          ["/" + path.join("/"), name_key]
        else
          ["/", name_key]
        end
      end
    end

    # Prune duplicate entries and sort with the most specific path first if there is more than one entry
    # In this case, sorting by the longest string works fine
    def optimize_index!
      @domain_index.each do |key, _val|
        # Sort each path/name_key pair by the longest path
        @domain_index[key].sort! { |a, b| b[0].size <=> a[0].size }.uniq!
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
  end
end

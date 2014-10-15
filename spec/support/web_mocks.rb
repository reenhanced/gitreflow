def stub_get(path, endpoint = GitReflow.git_server.class.api_endpoint)
  stub_request(:get, endpoint + path)
end

def stub_post(path, endpoint = GitReflow.git_server.class.api_endpoint)
  stub_request(:post, endpoint + path)
end

def stub_patch(path, endpoint = Github.endpoint.to_s)
  stub_request(:patch, endpoint + path)
end

def stub_put(path, endpoint = Github.endpoint.to_s)
  stub_request(:put, endpoint + path)
end

def stub_delete(path, endpoint = Github.endpoint.to_s)
  stub_request(:delete, endpoint + path)
end

def a_get(path, endpoint = Github.endpoint.to_s)
  a_request(:get, endpoint + path)
end

def a_post(path, endpoint = Github.endpoint.to_s)
  a_request(:post, endpoint + path)
end

def a_patch(path, endpoint = Github.endpoint.to_s)
  a_request(:patch, endpoint + path)
end

def a_put(path, endpoint = Github.endpoint)
  a_request(:put, endpoint + path)
end

def a_delete(path, endpoint = Github.endpoint)
  a_request(:delete, endpoint + path)
end

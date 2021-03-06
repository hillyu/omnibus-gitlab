require 'docker'

class DockerOperations
  def self.remove_containers
    puts 'Removing existing containers'
    containers = Docker::Container.all
    containers.each do |container|
      begin
        container.delete(v: true)
      rescue
        next
      end
    end
  end

  def self.remove_dangling_images
    puts 'Removing dangling images'
    dangling_images = Docker::Image.all(filters: '{"dangling":[ "true" ]}')
    dangling_images.each do |image|
      begin
        image.remove
      rescue
        next
      end
    end
  end

  def self.remove_existing_images(release_package)
    puts 'Removing existing images'
    images = Docker::Image.all
    images.each do |image|
      begin
        image.remove(force: true) if image.info["RepoTags"][0].include?(release_package)
      rescue
        next
      end
    end
  end

  def self.build(location, image, tag)
    Docker.options[:read_timeout] = 600
    Docker::Image.build_from_dir(location.to_s, { t: "#{image}:#{tag}", pull: true }) do |chunk|
      if (log = JSON.parse(chunk)) && log.key?("stream")
        puts log["stream"]
      end
    end
  end

  def self.authenticate(username = ENV['DOCKERHUB_USERNAME'], password = ENV['DOCKERHUB_PASSWORD'], serveraddress = "")
    Docker.authenticate!(username: username, password: password, serveraddress: serveraddress)
  end

  def self.push(image_id, initial_tag, new_tag, repo = "gitlab")
    # initial_tag specifies the tag used while building the image. It can be
    # 1. latest - for GitLab images
    # 2. ce-latest or ee-latest - for GitLab QA images
    image = Docker::Image.get("#{image_id}:#{initial_tag}")
    image.tag(repo: "#{repo}/#{image_id}", tag: new_tag, force: true)
    image.push(Docker.creds, repo_tag: "#{repo}/#{image_id}:#{new_tag}") do |chunk|
      puts chunk
    end
  end
end

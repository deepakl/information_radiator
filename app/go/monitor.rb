require 'nokogiri'
require 'http_handler'
require 'go/pipeline_filter'
require 'go/pipeline_orderer'

class GoMonitor
  def initialize hashie
    @http_handler = HttpHandler.new(go_base_url(hashie.url))
    @http_handler.auth(hashie.username, hashie.password) if hashie.username && hashie.password
    @pipeline_filter = GoPipelineFilter.new(@http_handler, hashie.pipelines.inclusions || [], hashie.pipelines.exclusions || [])
    @pipeline_orderer = GoPipelineOrderer.new(hashie.pipelines.order)
    @refresh_rate = hashie.refresh_rate || 15
  end
  attr_reader :refresh_rate

  def refresh_data
    begin
      pipelines = filter_pipelines(Nokogiri::XML(@http_handler.retrieve("/cctray.xml"))).sort
      @pipeline_orderer.apply(pipelines.each(&:refresh_data))
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
      raise "Cannot connect to GO server"
    end
  end
  
  def type
    "go"
  end
  
  private
  
  def filter_pipelines projects
    stages = projects.css("Project").find_all {|p| p["name"].split("::").size == 2 }.map {|attrs| GoStageBuilder.create(attrs)}
    @pipeline_filter.apply(stages)
  end
    
  def go_base_url url
    (url.match(/\/$/) ? url.chop : url) + "/go"
  end
end

class GoStageBuilder
  def self.create attrs
    pipeline_name, name = attrs["name"].split(" :: ")
    id = attrs["webUrl"].match(/\/go\/pipelines\/(.+)/)[1]
    GoStage.new(id: id, name: name, pipeline_name: pipeline_name, status: attrs["lastBuildStatus"], activity: attrs["activity"], label: attrs["lastBuildLabel"])
  end
end


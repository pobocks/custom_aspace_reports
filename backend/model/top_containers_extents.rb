class TopContainersExtents < AbstractReport
  include JSONModel
  @unit_conversions = {
    :inches => {
      :centimeters => 2.54,
      :feet => 1.0/12.0,
      :meters => 0.0254
    },
    :centimeters => {
      :inches => 0.393701,
      :feet => 0.0328084,
      :meters => 0.01
    },
    :feet => {
      :inches => 12.0,
      :centimeters => 2.54*12.0,
      :meters => 0.3048
    },
    :meters => {
      :inches => 39.3701,
      :feet => 3.28084,
      :centimeters => 100.0
    }
  }

  register_report( {
    :params => [['resourceids', 'ResourceIds', 'One or more Resource Identifiers (comma separated) of a resource to get containers for']]
   } )
   

  def initialize(params, job, db)
    super
    @unit_conversions = {
      :inches => {
        :centimeters => 2.54,
        :feet => 1.0/12.0,
        :meters => 0.0254
      },
      :centimeters => {
        :inches => 0.393701,
        :feet => 0.0328084,
        :meters => 0.01
      },
      :feet => {
        :inches => 12.0,
        :centimeters => 2.54*12.0,
        :meters => 0.3048
      },
      :meters => {
        :inches => 39.3701,
        :feet => 3.28084,
        :centimeters => 100.0
      }
    }
    @array = []  
    @volume = false
    @units = :inches
    @decimal_places_in_published_extent = 2
    @ids = ''
    rids = params.fetch('resourceids')    
    rids.split(',').each  do |id|
      @ids += db.literal('["' + id.strip + '",null,null,null]') + ','
    end
    @ids = @ids.chop
  end

  def get_content  
    topcon_rlshp = SubContainer.find_relationship(:top_container_link)
    query.each do |result|
      uri = "/repositories/#{@repo_id.to_s}/resources/#{result[:id].to_s}"
      parsed = JSONModel.parse_reference(uri)
      RequestContext.open(:repo_id => JSONModel(:repository).id_for(parsed[:repository])) do
        obj = Kernel.const_get(parsed[:type].to_s.camelize)[parsed[:id]]
        resource = obj.respond_to?(:root_record_id) ? obj.class.root_model[obj.root_record_id] : nil
        rel_ids = obj.object_graph.ids_for(topcon_rlshp)
        DB.open do |db|
          db[:top_container_link_rlshp].filter(:id => rel_ids).select(:top_container_id).distinct().map {|hash| hash[:top_container_id]}.each do |tc_id|
              row = {}
              row[:title] = result[:rtitle]
              identifier = result[:rident].gsub('null','').gsub('[','').gsub(']','')
              row[:identifier] = identifier
              tc = TopContainer[tc_id]
              row[:indicator] = tc.indicator
              prof = tc.related_records(:top_container_profile)
              if prof.nil? then
                row[:container_profile] = '*MISSING*'
                row[:width] = ''
              else
                row[:container_profile] = prof.display_string
                width = prof.width
                width = convert(width.to_f, prof.dimension_units.intern)
                row[:width] = width.round(@decimal_places_in_published_extent)
              end
              location = tc.related_records(:top_container_housed_at).first
              location &&= location.title
              row[:location] = location.nil? ? "" : location
              @array.push(row)
          end
        end
      end
    end
    info[:repository] = repository
    @array
  end
  def convert(val, unit)    
    @units ||= unit
    return val if unit == @units
    conv = @unit_conversions[unit.to_sym][@units.to_sym]
    conv = conv**3 if @volume
    val * conv
  end
  def query_string
    <<~SOME_SQL
          SELECT id,
                  REPLACE (title,","," ") AS rtitle,
                  REPLACE (identifier,","," ") AS rident
                  from resource where identifier IN (#{@ids})
        SOME_SQL
  end
end

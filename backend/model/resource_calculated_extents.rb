class ResourceCalculatedExtents < AbstractReport
  require 'uri'
  require 'net/http'
  include JSONModel

  register_report( {
    :params => [['resourceids', 'ResourceIds', 'One or more Resource Identifiers (comma separated) of a resource to get containers for'], ['details', 'Boolean', 'Include container details']]
  }  )

  def record_type
    'resource'
  end
  def initialize(params, job, db)
    super
    @detailed =params.fetch('details', false)
    resourceids = params.fetch('resourceids')
    rids = resourceids
    @ids = ""
    @extents = []
    @max_container_count = 0
    # create array for each id, .to_s it
    for id in rids.split(',') do
      @ids += db.literal('["' + id.strip + '",null,null,null]') + ','
    end
    @ids = @ids.chop
  end

  # since we're only  doing a sql query to get the resource.id, we override get_content!

  def get_content
    array = []
    query.each do |result|
      # url = "/extent_calculator?record_uri=/repositories/#{@repo_id.to_s}/resources/#{result[:id].to_s}"
      uri = "/repositories/#{@repo_id.to_s}/resources/#{result[:id].to_s}"
      get_calculations(uri, result)
    end
    # do the row stuff here!
    @extents.each do |ext|
      row = {}
      row[:identifier] = ext[:identifier].gsub('null','').gsub('[','').gsub(']','')
      row[:title] = ext[:title]
      row[:container_count] = ext[:container_count].nil? ? 0 : ext[:container_count]
      row[:missing_container_profile] = ext[:container_without_profile_count] == 0 ?  "No" : "Yes" 
      row[:total_extent] = extent_string(ext[:total_extent],ext[:volume], ext[:units])
      if @detailed then    
        (1..@max_container_count).to_a.each do |n|
          row[("container_#{n.to_s}").to_sym] = ""
          row[("number_#{n.to_s}").to_sym] = ""
          row[("extent_#{n.to_s}").to_sym] = ""
        end
        n = 1
        ext[:containers].each do |key, h|
          row[("container_#{n.to_s}").to_sym] = key
          row[("number_#{n.to_s}").to_sym] = h[:count].nil? ? 0 : h[:count]
          row[("extent_#{n.to_s}").to_sym] = extent_string(h[:extent], ext[:volume], ext[:units])
          n += 1
        end
        # here's where we add the detailed rows
      end
      array.push(row)
    end
    info[:repository] = repository
    array
  end

  def get_calculations(uri, result)
    # get the extent calculator model object and massage
    parsed = JSONModel.parse_reference(uri)
    RequestContext.open(:repo_id => JSONModel(:repository).id_for(parsed[:repository])) do
      obj = Kernel.const_get(parsed[:type].to_s.camelize)[parsed[:id]]
      ext_cal = ExtentCalculator.new(obj)
      ext_cal =  ext_cal.to_hash 
      ext_cal[:title] = result[:rtitle]
      ext_cal[:identifier] = result[:rident]
      if ext_cal[:container_count] > @max_container_count then
        @max_container_count = ext_cal[:container_count] 
      end
      @extents.push(ext_cal)       
    end
  end
 
  def extent_string(ext, vol, units)
    if ext == 0 then
      'None'
    else
      ext_string = ext.to_s + ' '
      ext_string += (vol ? 'cubic ' : 'linear ')
      ext_string  += units.to_s
    end
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

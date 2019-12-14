#!/usr/bin/env ruby
# encoding: utf-8
require 'sinatra'
require "bunny" #require for server connection
require "json" #require for json manipulation
require 'mongoid'

#DB setup
Mongoid.load! "mongoid.config"

#Models
class Request 
  include Mongoid::Document

  field :product, type: String
  field :user, type: String
  field :data_tables, type: Array
  field :samples, type: Array
  field :variables, type: Array

  validates :product, presence: true
  validates :user, presence: true
  validates :data_tables, presence: false
  validates :samples, presence: false
  validates :variables, presence: false
end

#for formatting
before do
  content_type 'application/json'
end


#endpoints
get '/res' do

    #connect to rabbitMQ and check for messages***************************/
    conn = Bunny.new()#credentials removed for security
    conn.start
    ch = conn.create_channel
    q  = ch.queue("reqs", :durable=> true)
    q.subscribe do |delivery_info, properties, payload|
    #parse JSON
    data=JSON.parse(payload)
    #save to mongodb
    request=Request.new(data).save
    end
    conn.close #close connection
    #**************************************************************************/

    #cycle through fields - this array could/should be dynamically generated*********/
    arrs = ['product', 'user', 'data_tables', 'samples', 'variables']
    res={}#define hash to store responses
    arrs.each do |a|
      attrs=Request.all.distinct(:"#{a}")#get a distinct current list of vals for each field
      curArr=[]#to store current array contents
      arrCnt={}#hash to store field name and count
      attrs.each do |d|#iterate thru field attributes to get count
      curArr=Request.where(:"#{a}" => d)#use the distinct list to filter
      arrCnt.store(d, curArr.length)#store the current value and # of times it's been used in a request
      end
      res.store(a, arrCnt)#add the current filter value and the count to the response array]
    end
    #**********************************************************************************/

    #similar but not...create two interations: one for samples, one for variables and match them up**/
    sample=Request.all.distinct(:samples)
    if sample.length>0 then #don't bother to continue if this filter is empty
      var=Request.all.distinct(:variables)
      if var.length>0 then #same with this one
        arrCnt={}
        #now iterate through again and grab intersecting requests to count
      sample.each do |s|
        var.each do |v|

        curArr=Request.and(:samples=>s, :variables=>v)
          if curArr.length>0 then #don't store if there're no results
          arrCnt.store("#{s}, #{v}", curArr.length)
          end
        end
      end
    res.store("sample variables", arrCnt)#add a title to the combo hash
  end
    JSON.pretty_generate(res)
    end
  #************************************************************************************************/
end


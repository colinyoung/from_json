require 'mongoid'

class Post
  include Mongoid::Document

  field :slug, type: String
  field :title, type: String
  
  index({ slug: 1 }, { unique: true })
end
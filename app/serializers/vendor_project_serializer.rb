class VendorProjectSerializer < ActiveModel::Serializer
  # cached true

  attributes :id,
             :slug,
             :title,
             :abstract,
             :body,
             :bids_due_at,
             :posted_at

  # def cache_key
  #   [object.cache_key, object.project.cache_key, scope ? scope.cache_key : 'no-scope', 'v12']
  # end
end

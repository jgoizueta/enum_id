require 'enum_id'

if defined? ActiveRecord::Base
  ActiveRecord::Base.extend EnumId
end

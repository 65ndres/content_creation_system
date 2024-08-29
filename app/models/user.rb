class User < ApplicationRecord
    has_many :sources
    has_many :stories
end

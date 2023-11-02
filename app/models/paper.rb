class Paper < ApplicationRecord
  has_many :mentions
  has_many :projects, through: :mentions
end

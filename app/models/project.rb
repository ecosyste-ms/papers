class Project < ApplicationRecord
  has_many :mentions
  has_many :papers, through: :mentions
end

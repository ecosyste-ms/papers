class Mention < ApplicationRecord
  belongs_to :paper
  belongs_to :project
  counter_culture :paper
  counter_culture :project
end

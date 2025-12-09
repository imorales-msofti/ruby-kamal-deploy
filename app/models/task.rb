class Task < ApplicationRecord
  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  
  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
end

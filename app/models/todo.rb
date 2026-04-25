# ABOUTME: Represents a single todo item in the demo application database.
# ABOUTME: Connects each todo to the owning user for the query log examples.
class Todo < ApplicationRecord
  belongs_to :user, inverse_of: :todos

  scope :ordered_by_created_desc, -> { order(created_at: :desc, id: :desc) }
  scope :completed, -> { where.not(status: "open") }

  def self.with_status(status)
    return all if status.blank? || status == "all"

    where(status: status)
  end

  def self.page(page, per_page)
    current_page = page.to_i
    current_page = 1 if current_page < 1

    page_size = per_page.to_i
    page_size = 50 if page_size < 1

    offset((current_page - 1) * page_size).limit(page_size)
  end

  def self.completed_for_user(user_id)
    where(user_id: user_id).completed
  end
end

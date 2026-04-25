# ABOUTME: Serves the demo todo endpoints that intentionally expose query anti-patterns.
# ABOUTME: Returns todo, status, and per-user stats data for the local collector demo.
class TodosController < ApplicationController
  def index
    todos = params[:q].present? ? Todo.where("title LIKE ?", "%#{params[:q]}%") : Todo.all
    render json: todos.as_json(include: :user)
  end

  def api_index
    order = params[:order].presence
    return head :bad_request if order.present? && order != "created_desc"

    todos = Todo.ordered_by_created_desc
    todos = todos.with_status(params[:status])
    todos = todos.page(params[:page], params[:per_page])

    render json: { items: todos.as_json(only: [:id, :user_id, :title, :status, :created_at, :updated_at]) }
  end

  def create
    todo = Todo.create!(todo_params)

    render json: todo.as_json(only: [:id, :user_id, :title, :status, :created_at, :updated_at]), status: :created
  end

  def update
    todo = Todo.find(params[:id])
    todo.update!(todo_update_params)

    render json: todo.as_json(only: [:id, :user_id, :title, :status, :created_at, :updated_at])
  end

  def completed
    deleted_count = Todo.completed_for_user(params.require(:user_id)).delete_all

    render json: { deleted_count: deleted_count }
  end

  def status
    render json: Todo.where(status: params.fetch(:status, "open"))
  end

  def stats
    render json: User.all.index_with { |user| user.todos.count }.transform_keys { |user| user.id.to_s }
  end

  private

  def todo_params
    params.permit(:user_id, :title, :status)
  end

  def todo_update_params
    params.permit(:title, :status)
  end
end

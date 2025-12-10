class TasksController < ApplicationController
  def index
    @tasks = Task.order(created_at: :desc)
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to root_path, notice: 'Task created successfully'
    else
      @tasks = Task.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def toggle
    @task = Task.find(params[:id])
    @task.update(completed: !@task.completed)
    redirect_to root_path
  end

  def destroy
    @task = Task.find(params[:id])
    @task.destroy
    redirect_to root_path, notice: 'Task deleted successfully'
  end

  private

  def task_params
    params.require(:task).permit(:title)
  end
end

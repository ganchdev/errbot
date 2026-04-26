# frozen_string_literal: true

class ProjectsController < ApplicationController

  before_action :require_admin
  before_action :set_project, only: [:edit, :update, :destroy]

  def index
    @projects = Project.order(:name)
    @project = Project.new
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project created."
    else
      @projects = Project.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to projects_path, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    project_name = @project.name
    @project.destroy!
    redirect_to projects_path, notice: "#{project_name} deleted."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :slug, :default_environment, :url)
  end

end

# frozen_string_literal: true

class IssuesController < ApplicationController

  before_action :set_issue

  def show
  end

  def resolve
    @issue.resolve!
    redirect_to issue_path(@issue), notice: "Issue resolved."
  end

  def ignore
    @issue.ignore!
    redirect_to issue_path(@issue), notice: "Issue ignored."
  end

  def reopen
    @issue.reopen!
    redirect_to issue_path(@issue), notice: "Issue reopened."
  end

  private

  def set_issue
    @issue = Issue.includes(:project).find(params[:id])
  end

end

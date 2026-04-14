# frozen_string_literal: true

class IssuesController < ApplicationController

  before_action :set_issue
  before_action :set_latest_event, only: [:show, :event_json]

  def show
    @stack_frames = @latest_event&.preferred_stack_frames || []
  end

  def event_json
    return head :not_found if @latest_event.blank?

    render plain: JSON.pretty_generate(@latest_event.parsed_payload), content_type: "application/json"
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
    @issue = Issue.includes(:project, :events).find(params[:id])
  end

  def set_latest_event
    @latest_event = @issue.events.order(occurred_at: :desc, id: :desc).first
  end

end

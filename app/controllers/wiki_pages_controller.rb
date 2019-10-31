class WikiPagesController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_action :member_only, :except => [:index, :search, :show, :show_or_new]
  before_action :builder_only, :only => [:destroy]
  before_action :normalize_search_params, :only => [:index]
  layout "sidebar"

  def new
    @wiki_page = WikiPage.new(wiki_page_params(:create))
    respond_with(@wiki_page)
  end

  def edit
    @wiki_page = WikiPage.find(params[:id])
    respond_with(@wiki_page)
  end

  def index
    @wiki_pages = WikiPage.paginated_search(params)

    if params[:redirect].to_s.truthy? && @wiki_pages.one?
      redirect_to @wiki_pages.first
    else
      respond_with(@wiki_pages)
    end
  end

  def search
    render layout: "default"
  end

  def show
    if params[:id] =~ /\A\d+\z/
      @wiki_page = WikiPage.find(params[:id])
    else
      @wiki_page = WikiPage.titled(params[:id]).first
    end

    if @wiki_page.present?
      respond_with(@wiki_page)
    elsif request.format.html?
      redirect_to show_or_new_wiki_pages_path(title: params[:id])
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def create
    @wiki_page = WikiPage.create(wiki_page_params(:create))
    respond_with(@wiki_page)
  end

  def update
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.update(wiki_page_params(:update))
    respond_with(@wiki_page)
  end

  def destroy
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.update(is_deleted: true)
    respond_with(@wiki_page)
  end

  def revert
    @wiki_page = WikiPage.find(params[:id])
    @version = @wiki_page.versions.find(params[:version_id])
    @wiki_page.revert_to!(@version)
    flash[:notice] = "Page was reverted"
    respond_with(@wiki_page)
  end

  def show_or_new
    @wiki_page = WikiPage.find_by_title(params[:title])

    if params[:title].blank?
      redirect_to new_wiki_page_path(wiki_page_params(:create))
    elsif @wiki_page.present?
      redirect_to wiki_page_path(@wiki_page)
    else
      @wiki_page = WikiPage.new(:title => params[:title])
      respond_with(@wiki_page)
    end
  end

  private

  def normalize_search_params
    if params[:title]
      params[:search] ||= {}
      params[:search][:title] = params.delete(:title)
    end
  end

  def wiki_page_params(context)
    permitted_params = %i[body other_names other_names_string skip_secondary_validations]
    permitted_params += %i[is_locked is_deleted] if CurrentUser.is_builder?
    permitted_params += %i[title] if context == :create || CurrentUser.is_builder?

    params.fetch(:wiki_page, {}).permit(permitted_params)
  end
end

class Platform::Application < ActiveRecord::Base
  set_table_name :platform_applications
  
  # useful methods - should be public
  include Platform::SimpleStringPermissions

  belongs_to :developer, :class_name => "Platform::Developer"
  has_many :application_developers, :class_name => "Platform::ApplicationDeveloper", :dependent => :destroy
  has_many :application_metrics, :class_name => "Platform::ApplicationMetric", :dependent => :destroy
  has_many :application_users, :class_name => "Platform::ApplicationUser", :dependent => :destroy
  has_many :application_logs, :class_name => "Platform::ApplicationLog", :dependent => :destroy
  
  has_many :tokens,           :class_name => "Platform::Oauth::OauthToken", :dependent => :destroy
  has_many :access_tokens,    :class_name => "Platform::Oauth::AccessToken", :dependent => :destroy
  has_many :verifier_tokens,  :class_name => "Platform::Oauth::VerifierToken", :dependent => :destroy

  has_many :application_categories,  :class_name => "Platform::ApplicationCategory", :dependent => :destroy
  has_many :categories,  :class_name => "Platform::Category", :through => :application_categories

  belongs_to :icon, :class_name => "Platform::Media::Image", :foreign_key => "icon_id"
  belongs_to :logo, :class_name => "Platform::Media::Image", :foreign_key => "logo_id"

  validates_presence_of :name, :key, :secret
  validates_uniqueness_of :key
  before_validation_on_create :generate_keys

  URL_REGEX = /\Ahttp(s?):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/i
  validates_format_of :url,                   :with => URL_REGEX, :allow_blank=>true
  validates_format_of :support_url,           :with => URL_REGEX, :allow_blank=>true
  validates_format_of :callback_url,          :with => URL_REGEX, :allow_blank=>true
  validates_format_of :support_url,           :with => URL_REGEX, :allow_blank=>true
  validates_format_of :privacy_policy_url,    :with => URL_REGEX, :allow_blank=>true
  validates_format_of :terms_of_service_url,  :with => URL_REGEX, :allow_blank=>true
  validates_format_of :canvas_url,            :with => URL_REGEX, :allow_blank=>true

  attr_accessor :token_callback_url

  acts_as_state_machine :initial => :new
  state :new
  state :submitted
  state :approved
  state :rejected 
  state :blocked 
  
  event :submit do
    transitions :from => :new,        :to => :submitted
    transitions :from => :rejected,   :to => :submitted
  end
  
  event :block do
    transitions :from => :new,        :to => :blocked
    transitions :from => :submitted,  :to => :blocked
    transitions :from => :approved,   :to => :blocked
    transitions :from => :rejected,   :to => :blocked
  end

  event :unblock do
    transitions :from => :blocked,    :to => :new
  end

  event :approve do
    transitions :from => :new,        :to => :approved
    transitions :from => :submitted,  :to => :approved
  end

  event :reject do
    transitions :from => :submitted,  :to => :rejected
  end
  
  def self.find_token(token_key)
    token = Platform::Oauth::OauthToken.find_by_token(token_key, :include => :application)
    if token && token.authorized?
      token
    else
      nil
    end
  end

  def last_token_for_user(user)
    Platform::Oauth::OauthToken.find(:first, :conditions => ["application_id = ? and user_id = ?", self.id, user.id], :order => "updated_at desc")
  end

  def valid_tokens_for_user(user)
    Platform::Oauth::OauthToken.find(:all, :conditions => ["application_id = ? and user_id = ? and invalidated_at is null", self.id, user.id])
  end

  def rate_limited(value=true)
    set_permission(:no_rate_limit, !value)
  end

  def rate_limited!(value=true)
    rate_limited(value)
    save!
  end

  def rate_limited?
    ! has_permission?(:no_rate_limit)
  end

  # Ticket 19135
  def allow_grant_type_password(value=true)
    set_permission(:grant_type_password, value)
  end

  # Ticket 19135
  def allow_grant_type_password!(value=true)
    allow_grant_type_password(value)
    save!
  end

  # Ticket 19135
  def allow_grant_type_password?
    has_permission?(:grant_type_password)
  end

  # Ticket 19180
  def allow_unlimited_models(value=true)
    set_permission(:unlimited_models, value)
  end

  # Ticket 19180
  def allow_unlimited_models!(value=true)
    allow_unlimited_models(value)
    save!
  end

  # Ticket 19180
  def allow_unlimited_models?
    has_permission?(:unlimited_models)
  end

  # Ticket 19507
  def allow_add_without_premium(value=true)
    set_permission(:add_without_premium, value)
  end

  # Ticket 19507
  def allow_add_without_premium!(value=true)
    allow_add_without_premium(value)
    save!
  end

  # Ticket 19507
  def allow_add_without_premium?
    has_permission?(:add_without_premium)
  end

  # If your application requires passing in extra parameters handle it here
  def create_request_token(params={})
    Platform::Oauth::RequestToken.create(params.merge(:application => self))
  end

  def create_access_token(params={})
    Platform::Oauth::AccessToken.create(params.merge(:application => self))
  end

  def create_refresh_token(params={})
    Platform::Oauth::RefreshToken.create(params.merge(:application => self))
  end

  def admin_link
    "#{DEFAULT_SITE_LINK}/admin/applications/view/#{id}"
  end

  def self.permissions
    [:no_rate_limit, :grant_type_password, :unlimited_models, :add_without_premium]
  end
  
  def icon_url
    return "/platform/images/default_app_icon.gif" unless icon
    icon.url
  end
  
  def store_icon(file)
    self.icon = Platform::Media::Image.create
    self.icon.write(file, :size => 16)
    self.save
  end

  def logo_url
    return "/platform/images/default_app_logo.gif" unless logo
    logo.url
  end

  def store_logo(file)
    self.logo = Platform::Media::Image.create
    self.logo.write(file, :size => 75)
    self.save
  end
  
  def short_description
    return description if description.blank? or description.length < 400
    "#{description[0..400]}..."
  end
  
  def app_url
    return url if canvas_name.blank?      
    "http://#{SITE}/platform/apps/#{canvas_name}"
  end
  
  def short_name
    return name if name.length < 15
    "#{name[0..15]}..."
  end
  
  def update_rank!
    total_rank = (rating_count == 0) ? 0 : (rating_sum/rating_count)
    self.update_attributes(:rank => total_rank)
    total_rank
  end
  
  def developed_by?(dev = Platform::Config.current_developer)
    self.developer == dev
  end
  
  def rating_count
    @rating_count ||= Platform::Rating.count(:id, :conditions => ["object_type = ? and object_id = ?", self.class.name, self.id])
  end

  def rating_sum
    @rating_sum ||= Platform::Rating.sum(:value, :conditions => ["object_type = ? and object_id = ?", self.class.name, self.id])
  end
  
  def reset_secret!
    update_attributes(:secret => Platform::Helper.generate_key(40)[0,40])
  end

  def authorize_user(user = Platform::Config.current_user)
    Platform::ApplicationUser.touch(self, user)
  end
  
  def authorized_user?(user = Platform::Config.current_user)
    not Platform::ApplicationUser.find(:first, :conditions => ["application_id = ? and user_id = ?", self.id, user.id]).nil?
  end
  
  def deauthorize_user(user = Platform::Config.current_user)
    valid_tokens_for_user(user).each do |token|
      token.invalidate!
    end
    app_user = Platform::ApplicationUser.for(self, user)
    app_user.destroy if app_user
    
    # ping the deauthorization url - maybe that should be done in a task
  end
  
  # grant type password apps should require signature
  def requires_signature?
    false      
  end
  
  def last_monthly_metric
    @last_monthly_metric ||= Platform::MonthlyApplicationMetric.find(:first, :conditions => ["application_id = ?", id], :order => "interval desc")
  end

  def last_total_metric
    @last_total_metric ||= Platform::TotalApplicationMetric.find(:first, :conditions => ["application_id = ?", id], :order => "interval desc")
  end
  
  def recently_updated_reviews
    @recently_updated_reviews ||= Platform::Rating.find(:all, :conditions => ["object_type = ? and object_id = ?", 'Platform::Application', self.id], :order => "updated_at desc", :limit => 5)    
  end

  def recently_updated_discussions
    @recently_updated_discussions ||= Platform::ForumTopic.find(:all, :conditions => ["subject_type = ? and subject_id = ?", 'Platform::Application', self.id], :order => "updated_at desc", :limit => 5)    
  end
  
  
  ############################################################################
  #### Category Management Methods
  ############################################################################
  
  def category_names
    categories.collect{|cat| cat.name}.join(", ")
  end

  def add_category(cat)
    cat = Platform::Category.find_by_keyword(cat) if cat.is_a?(String)
    return nil if not cat
    
    Platform::ApplicationCategory.find_or_create(self, cat)
  end

  def add_categories(catigories)
    catigories.each do |cat|
      add_category(cat)
    end
  end
  
  def remove_category(cat)
    cat = Platform::Category.find_by_keyword(cat) if cat.is_a?(String)
    return nil if not cat
    
    app_cat = Platform::ApplicationCategory.find_by_application_id_and_category_id(self.id, cat.id)
    app_cat.destroy if app_cat                                                
  end

  def remove_categories(categories)
    categories.each do |cat|
      remove_category(cat)
    end
  end  
  
  def self.featured_for_category(category, page = 1, per_page = 20)
    paginate(:conditions => ["platform_applications.state='approved' and platform_application_categories.category_id = ? and platform_application_categories.featured = ?", category.id, true], 
             :joins => "inner join platform_application_categories on platform_application_categories.application_id = platform_applications.id", 
             :order => "platform_application_categories.position asc", :page => page, :per_page => per_page)
  end
  
  def self.regular_for_category(category, page = 1, per_page = 20)
    paginate(:conditions => ["platform_applications.state='approved' and platform_application_categories.category_id = ? and (platform_application_categories.featured is null or platform_application_categories.featured = ?)", category.id, false], 
             :joins => "inner join platform_application_categories on platform_application_categories.application_id = platform_applications.id", 
             :order => "platform_application_categories.position asc", :page => page, :per_page => per_page)
  end
  
protected

  def generate_keys
    self.key = Platform::Helper.generate_key(40)[0,40] if key.nil?
    self.secret = Platform::Helper.generate_key(40)[0,40] if secret.nil?
  end

#  after_create :notify_admins
#  def notify_admins
#    return unless Registry.api.admin_email?
#    return unless Platform::Config.current_user
#    
#    message = "#{Platform::Config.current_user.name} (#{Platform::Config.current_user.admin_link}) has created an app called #{name} (#{admin_link})."
#    SystemNotifier.deliver_to_admin(message, :subject => 'Client Application Created', :to => Registry.api.admin_email)
#  end

end

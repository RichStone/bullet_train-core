class User < ApplicationRecord
  # 🚫 DEFAULT BULLET TRAIN USER FUNCTIONALITY
  # Typically you should avoid adding your own functionality in this section to avoid merge conflicts in the future.
  # (If you specifically want to change Bullet Train's default behavior, that's OK and you can do that here.)

  if two_factor_authentication_enabled?
    devise :two_factor_authenticatable, :two_factor_backupable, :omniauthable,
      :registerable, :recoverable, :rememberable, :trackable, :validatable,
      otp_secret_encryption_key: ENV["TWO_FACTOR_ENCRYPTION_KEY"]
  else
    devise :omniauthable, :database_authenticatable, :registerable,
      :recoverable, :rememberable, :trackable, :validatable
  end

  # teams
  has_many :memberships, dependent: :destroy
  has_many :scaffolding_absolutely_abstract_creative_concepts_collaborators, through: :memberships
  has_many :teams, through: :memberships
  belongs_to :current_team, class_name: "Team", optional: true
  accepts_nested_attributes_for :current_team

  # oauth providers
  has_many :oauth_stripe_accounts, class_name: "Oauth::StripeAccount" if stripe_enabled?

  # platform functionality.
  belongs_to :platform_agent_of, class_name: "Platform::Application", optional: true

  # validations
  validate :real_emails_only
  validates :time_zone, inclusion: {in: ActiveSupport::TimeZone.all.map(&:name)}, allow_nil: true

  # callbacks
  after_update :set_teams_time_zone

  # ✅ YOUR APPLICATION'S USER FUNCTIONALITY
  # This is the place where you should implement your own features on top of Bullet Train's user functionality. There
  # are a bunch of Super Scaffolding hooks here by default to try and help keep generated code logically organized.

  # 🚅 add concerns above.

  # 🚅 add belongs_to associations above.

  # 🚅 add has_many associations above.

  # 🚅 add oauth providers above.

  # 🚅 add has_one associations above.

  # 🚅 add scopes above.

  # 🚅 add validations above.

  # 🚅 add callbacks above.

  # 🚅 add delegations above.

  # 🚅 add methods above.

  # 🚫 DEFAULT BULLET TRAIN USER FUNCTIONALITY
  # We put these at the bottom of this file to keep them out of the way. You should define your own methods above here.

  # TODO we need to update this to some sort of invalid email address or something
  # people know to ignore. it would be a security problem to have this pointing
  # at anybody's real email address.
  def email_is_oauth_placeholder?
    !!email.match(/noreply\+.*@bullettrain.co/)
  end

  def label_string
    name
  end

  def name
    full_name.present? ? full_name : email
  end

  def full_name
    [first_name_was, last_name_was].select(&:present?).join(" ")
  end

  def details_provided?
    first_name.present? && last_name.present? && current_team.name.present?
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end

  def create_default_team
    # This creates a `Membership`, because `User` `has_many :teams, through: :memberships`
    # TODO The team name should take into account the user's current locale.
    default_team = teams.create(name: "Your Team", time_zone: time_zone)
    memberships.find_by(team: default_team).update role_ids: [Role.admin.id]
    update(current_team: default_team)
  end

  def real_emails_only
    if ENV["REALEMAIL_API_KEY"] && !Rails.env.test?
      uri = URI("https://realemail.expeditedaddons.com")

      # Change the input parameters here
      uri.query = URI.encode_www_form({
        api_key: ENV["REAL_EMAIL_KEY"],
        email: email,
        fix_typos: false
      })

      # Results are returned as a JSON object
      result = JSON.parse(Net::HTTP.get_response(uri).body)

      if result["syntax_error"]
        errors.add(:email, "is not a valid email address")
      elsif result["domain_error"] || (result.key?("mx_records_found") && !result["mx_records_found"])
        errors.add(:email, "can't actually receive emails")
      elsif result["is_disposable"]
        errors.add(:email, "is a disposable email address")
      end
    end
  end

  def multiple_teams?
    teams.count > 1
  end

  def one_team?
    !multiple_teams?
  end

  def formatted_email_address
    if details_provided?
      "\"#{first_name} #{last_name}\" <#{email}>"
    else
      email
    end
  end

  def parent_ids_for(role, model, through, parent)
    parent_id_column = "#{parent}_id"
    key = "#{role.key}_#{through}_#{parent_id_column}s"
    return ability_cache[key] if ability_cache && ability_cache[key]
    role = nil if role.default?
    value = send(through).with_role(role).distinct.pluck(parent_id_column)
    current_cache = ability_cache || {}
    current_cache[key] = value
    update_column :ability_cache, current_cache
    value
  end

  def invalidate_ability_cache
    update_column(:ability_cache, {})
  end

  def otp_qr_code
    issuer = I18n.t("application.name")
    label = "#{issuer}:#{email}"
    RQRCode::QRCode.new(otp_provisioning_uri(label, issuer: issuer))
  end

  def scaffolding_absolutely_abstract_creative_concepts_collaborators
    Scaffolding::AbsolutelyAbstract::CreativeConcepts::Collaborator.joins(:membership).where(membership: {user_id: id})
  end

  def admin_scaffolding_absolutely_abstract_creative_concepts_ids
    scaffolding_absolutely_abstract_creative_concepts_collaborators.admins.pluck(:creative_concept_id)
  end

  def editor_scaffolding_absolutely_abstract_creative_concepts_ids
    scaffolding_absolutely_abstract_creative_concepts_collaborators.editors.pluck(:creative_concept_id)
  end

  def viewer_scaffolding_absolutely_abstract_creative_concepts_ids
    scaffolding_absolutely_abstract_creative_concepts_collaborators.viewers.pluck(:creative_concept_id)
  end

  def developer?
    return false unless ENV["DEVELOPER_EMAILS"]
    # we use email_was so they can't try setting their email to the email of an admin.
    return false unless email_was
    ENV["DEVELOPER_EMAILS"].split(",").include?(email_was)
  end

  def set_teams_time_zone
    teams.where(time_zone: nil).each do |team|
      team.update(time_zone: time_zone) if team.users.count == 1
    end
  end
end

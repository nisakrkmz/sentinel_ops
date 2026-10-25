require "openssl"

# Operator account stored in the database. Every user owns exactly one human
# Actor, so UI actions keep the existing actor-based audit trail.
#
# Passwords use PBKDF2-HMAC-SHA256 from Ruby's OpenSSL stdlib with a per-user
# random salt, stored as "pbkdf2_sha256$<iterations>$<salt>$<hash>".
class User < ApplicationRecord
  ALGORITHM = "pbkdf2_sha256".freeze
  ITERATIONS = Rails.env.test? ? 1_000 : 210_000
  MINIMUM_PASSWORD_LENGTH = 10
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  belongs_to :actor

  attr_reader :password

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :name, with: ->(name) { name.to_s.squish }

  validates :email, presence: { message: "E-posta gerekli" },
    uniqueness: { message: "Bu e-posta ile kayıtlı bir hesap var" },
    format: { with: EMAIL_FORMAT, message: "Geçerli bir e-posta girin" }
  validates :name, presence: { message: "Ad Soyad gerekli" }, length: { maximum: 60 }
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH, message: "Şifre en az #{MINIMUM_PASSWORD_LENGTH} karakter olmalı" }, allow_nil: true
  validates :password_digest, presence: true
  validate :password_confirmation_matches

  attr_accessor :password_confirmation

  before_validation :ensure_actor, on: :create

  # Public demo account for the hosted demo (config/demo_operator.yml), or nil when
  # DEMO_OPERATOR_ENABLED=false.
  def self.demo_operator
    return if ENV["DEMO_OPERATOR_ENABLED"] == "false"

    @demo_operator ||= YAML.safe_load_file(Rails.root.join("config/demo_operator.yml")).symbolize_keys.freeze
  end

  def self.authenticate(email, password)
    user = find_by(email: email.to_s.strip.downcase)
    return user if user&.authenticate(password)

    # Spend comparable time when the email is unknown so responses do not reveal accounts.
    new.send(:digest_for, password.to_s, SecureRandom.hex(16), ITERATIONS) unless user
    nil
  end

  def password=(value)
    @password = value
    return if value.nil?

    salt = SecureRandom.hex(16)
    self.password_digest = [ ALGORITHM, ITERATIONS, salt, digest_for(value.to_s, salt, ITERATIONS) ].join("$")
  end

  def authenticate(value)
    algorithm, iterations, salt, expected = password_digest.to_s.split("$", 4)
    return false unless algorithm == ALGORITHM && expected.present?

    candidate = digest_for(value.to_s, salt, iterations.to_i)
    ActiveSupport::SecurityUtils.secure_compare(candidate, expected)
  end

  def initials
    name.split.first(2).map { |part| part[0] }.join.upcase.presence || "?"
  end

  private

  def digest_for(value, salt, iterations)
    OpenSSL::KDF.pbkdf2_hmac(value, salt: salt, iterations: iterations, length: 32, hash: "sha256").unpack1("H*")
  end

  def password_confirmation_matches
    return if password.nil? || password_confirmation.nil?

    errors.add(:base, "Şifre tekrarı eşleşmiyor") unless password == password_confirmation
  end

  # Reuses an unclaimed human actor with the same name (keeps earlier audit history
  # attributed to it); otherwise disambiguates the actor name with the email.
  def ensure_actor
    return if actor || name.blank?

    existing = Actor.find_by(kind: :human, name: name)
    actor_name = existing.nil? || !User.exists?(actor_id: existing.id) ? name : "#{name} (#{email})"
    self.actor = Actor.find_or_create_by!(kind: :human, name: actor_name)
  end
end

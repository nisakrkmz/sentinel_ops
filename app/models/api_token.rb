require "openssl"
require "securerandom"

class ApiToken < ApplicationRecord
  belongs_to :actor

  attr_reader :plaintext_token

  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_must_be_an_array
  validate :actor_must_be_active

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.issue!(actor:, scopes:, pepper: ENV["AGENT_TOKEN_PEPPER"])
    raise ArgumentError, "AGENT_TOKEN_PEPPER must be configured" if pepper.blank?

    plaintext = SecureRandom.urlsafe_base64(32)
    record = create!(
      actor: actor,
      scopes: scopes,
      token_digest: digest(plaintext, pepper)
    )
    record.instance_variable_set(:@plaintext_token, plaintext)
    record
  end

  def self.authenticate(plaintext, pepper: ENV["AGENT_TOKEN_PEPPER"])
    raise ArgumentError, "AGENT_TOKEN_PEPPER must be configured" if pepper.blank?
    return if plaintext.blank?

    token = active.joins(:actor).where(actors: { active: true }).find_by(token_digest: digest(plaintext, pepper))
    return unless token

    token.update!(last_used_at: Time.current)
    token
  end

  def self.digest(plaintext, pepper)
    OpenSSL::HMAC.hexdigest("SHA256", pepper, plaintext)
  end
  private_class_method :digest

  def allows?(required_scope)
    scopes.include?(required_scope.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  private

  def scopes_must_be_an_array
    unless scopes.is_a?(Array)
      errors.add(:scopes, "must be an array")
      return
    end

    if actor && (scopes - actor.scopes).any?
      errors.add(:scopes, "must be granted to the actor")
    end
  end

  def actor_must_be_active
    errors.add(:actor, "must be active") if actor && !actor.active?
  end
end

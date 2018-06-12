defmodule Hexpm.Accounts.Email do
  use Hexpm.Web, :schema

  @derive Hexpm.Web.Stale
  @email_regex ~r"^.+@.+\..+$"

  schema "emails" do
    field :email, :string
    field :verified, :boolean, default: false
    field :primary, :boolean, default: false
    field :public, :boolean, default: false
    field :gravatar, :boolean, default: false
    field :verification_key, :string
    field :verification_expiry, :naive_datetime

    belongs_to :user, User

    timestamps()
  end

  def changeset(email, type, params, verified? \\ not Application.get_env(:hexpm, :user_confirm))

  def changeset(email, :first, params, verified?) do
    changeset(email, :create, params, verified?)
    |> put_change(:primary, true)
    |> put_change(:public, true)
  end

  def changeset(email, :create, params, verified?) do
    cast(email, params, ~w(email)a)
    |> validate_required(~w(email)a)
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, @email_regex)
    |> validate_confirmation(:email, message: "does not match email")
    |> validate_verified_email_exists(:email, message: "already in use")
    |> unique_constraint(:email, name: "emails_email_key")
    |> unique_constraint(:email, name: "emails_email_user_key")
    |> put_change(:verified, verified?)
    |> put_change(:verification_key, Auth.gen_key())
    |> put_change(:verification_expiry, NaiveDateTime.utc_now())
  end

  def verification(email) do
    change(email, %{
      verification_key: Auth.gen_key(),
      verification_expiry: NaiveDateTime.utc_now()
    })
  end

  def verify?(nil, _key), do: false

  def verify?(email, key) do
    email_key = email.verification_key
    valid_key? = !!(email_key && Hexpm.Utils.secure_check(email_key, key))
    within_time? = Hexpm.Utils.within_last_day?(email.verification_expiry)
    valid_key? and within_time?
  end

  def verify(email) do
    change(email, %{
      verified: true,
      verification_key: nil,
      verification_expiry: nil
    })
    |> unique_constraint(:email, name: "emails_email_key", message: "already in use")
  end

  def toggle_flag(email, flag, value) do
    change(email, %{flag => value})
  end

  def order_emails(emails) do
    Enum.sort_by(emails, &[not &1.primary, not &1.public, not &1.verified, -&1.id])
  end
end

require 'spec_helper'

describe User, :type => :model do
  let(:user) { build(:user) }
  let(:named) { user }

  let(:unnamed) { build(:user) { |u| u.owner_name = nil } }

  let(:activatable) { user }
  let(:owner) { user }
  let(:owned) { build(:project, owner: user) }

  it_behaves_like "is owner nameable"
  it_behaves_like "activatable"
  it_behaves_like "is an owner"

  describe "links" do
    it "should allow membership links to any user" do
      expect(User).to link_to(Membership).with_scope(:all)
    end
    
    it "should allow user_gruop links to any user" do
      expect(User).to link_to(UserGroup).with_scope(:all)
    end
  end

  describe '::from_omniauth' do
    let(:auth_hash) { OmniAuth.config.mock_auth[:facebook] }

    shared_examples 'new user from omniauth' do
      let(:user_from_auth_hash) do
        user = User.from_omniauth(auth_hash)
      end

      it 'should create a new valid user' do
        expect(user_from_auth_hash).to be_valid
      end

      it 'should create a user with the same details' do
        expect(user_from_auth_hash.email).to eq(auth_hash.info.email)
        expect(user_from_auth_hash.display_name).to eq(auth_hash.info.name)
      end

      it 'should create a user with a login' do
        expect(user_from_auth_hash.login).to eq(auth_hash.info.name.downcase.gsub(/\s/, '_'))
      end

      it 'should create a user with a authorization' do
        expect(user_from_auth_hash.authorizations).to all( be_an(Authorization) )
      end
    end

    context 'a new user with email' do
      it_behaves_like 'new user from omniauth'
    end

    context 'a user without an email' do
      let(:auth_hash) { OmniAuth.config.mock_auth[:facebook_no_email] }

      it 'should not have an email' do
        expect(User.from_omniauth(auth_hash).email).to be_nil
      end

      it_behaves_like 'new user from omniauth'
    end

    context 'an existing user' do
      let!(:omniauth_user) { create(:omniauth_user) }

      it 'should return the existing user' do
        expect(User.from_omniauth(auth_hash)).to eq(omniauth_user)
      end
    end

    context 'an invalid user' do
      it 'should raise an exception' do
        create(:user, email: 'examplar@example.com')
        auth_hash = OmniAuth.config.mock_auth[:gplus]
        expect{ User.from_omniauth(auth_hash) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe '#login' do
    it 'should validate presence' do
      expect(build(:user, login: "").valid?).to be false
    end

    it 'should have non-blank error' do
      user = build(:user, login: "")
      user.valid?
      expect(user.errors[:login]).to include("can't be blank")
    end

    it 'should validate uniqueness' do
      login = 't'
      expect{ create(:user, login: login) }.to_not raise_error
      expect{ create(:user, login: login.upcase, email: 'test2@example.com') }.to raise_error
      expect{ create(:user, login: login.downcase, email: 'test3@example.com') }.to raise_error
    end

    it "should have the correct case-insensitive uniqueness error" do
      user = create(:user)
      dup_user = build(:user, login: user.login.upcase)
      dup_user.valid?
      expect(dup_user.errors[:login]).to include("has already been taken")
    end

    context "when a user_group with the same name in different case exists" do
      let!(:user_group) { create(:user_group, name: user.owner_uniq_name.upcase) }

      it "should not be valid" do
        expect(user).to_not be_valid
      end

      it "should have the correct error message on the owner_name association" do
        user.valid?
        expect(user.errors[:"owner_name.name"]).to include("has already been taken")
      end
    end
  end

  describe '#email' do

    context "when a user is setup" do
      let(:user) { create(:user, email: 'test@example.com') }

      it 'should raise an error trying to save a duplcate' do
        expect{ create(:user, email: user.email.upcase) }.to raise_error
      end

      it 'should validate case insensitive uniqueness' do
        dup = build(:user, email: user.email.upcase)
        dup.valid?
        expect(dup.errors[:email]).to include("has already been taken")
      end
    end

    context "when a user is disabled and has no email" do
      subject { build(:user, email: nil, activated_state: :inactive) }

      it { is_expected.to be_valid }
    end
    
  end

  describe "#password_required?" do
    it 'should require a password when creating with a new user' do
      expect{ create(:user, password: "password1") }.to_not raise_error
      expect{ create(:user, password: nil) }.to raise_error
    end

    it 'should not require a password when creating a user from an import' do
      attrs = {login: "t", hash_func: 'sha1', email: "test@example.com"}
      expect do
        User.create!(attrs) do |user|
          user.owner_name = OwnerName.new(name: "t", resource: user)
        end
      end.to_not raise_error
    end
  end

  describe "#valid_password?" do
    it 'should validate user with bcrypted password' do
      expect(create(:user).valid_password?('password')).to be_truthy
    end

    it 'should validate imported user with sha1+salt password' do
      expect(create(:insecure_user).valid_password?('tajikistan')).to be_truthy
    end

    it 'should update an imported user to use bcrypt hashing' do
      user = create(:insecure_user)
      user.valid_password?('tajikistan')
      expect(user.hash_func).to eq("bcrypt")
    end

    it 'should validate length of user passwords' do
      user_errors = ->(attrs){ User.new(attrs).tap{ |u| u.valid? }.errors }
      expect(user_errors.call(password: 'ab12')).to have_key :password
      expect(user_errors.call(password: 'abcd1234')).to_not have_key :password
      expect(user_errors.call(migrated_user: true, password: 'ab')).to have_key :password
      expect(user_errors.call(migrated_user: true, password: 'ab12')).to_not have_key :password
    end
  end

  describe "#admin" do
    let(:user) { build(:user) }

    it "should be false" do
      expect(user.admin).to be false
    end

    context "without an admin value" do
      before(:each) do
        user.admin = nil
      end

      it "should not be valid without an admin value" do
        expect(user).to_not be_valid
      end

      it "should have the correct error message" do
        user.valid?
        expect(user.errors[:admin]).to include("must be a boolean value")
      end
    end
  end

  describe "#active_for_authentication?" do
    let(:user) { create(:user) }

    it "should return true for an active user" do
      expect(user.active_for_authentication?).to eq(true)
    end

    it "should be false for a disabled user" do
      user.disable!
      expect(user.active_for_authentication?).to eq(false)
    end
  end

  describe "#languages" do

    context "when no languages are set" do

      it "should return an emtpy array for no set languages" do
        user = build(:user)
        expect(user.languages).to match_array([])
      end
    end
  end

  describe "#projects" do
    let(:user) { create(:project_owner) }

    it "should have many projects" do
      expect(user.projects).to all( be_a(Project) )
    end
  end

  describe "#memberships" do
    let(:user) { create(:user_group_member) }

    it "should have many user group members" do
      expect(user.memberships).to all( be_a(Membership) )
    end
  end

  describe "#user_groups" do
    let(:user) { create(:user_group_member) }

    it "should be a member of many user groups" do
      expect(user.user_groups).to all( be_a(UserGroup) )
    end
  end

  describe "#collections" do
    let(:user) { create(:user_with_collections) }

    it "should have many collections" do
      expect(user.collections).to all( be_a(Collection) )
    end
  end

  describe "#subjects" do
    let(:relation_instance) { user }

    it_behaves_like "it has a subjects association"
  end

  describe "#classifications" do
    let(:relation_instance) { user }

    it_behaves_like "it has a classifications assocation"
  end

  describe "#classifcations_count" do
    let(:relation_instance) { user }

    it_behaves_like "it has a cached counter for classifications"
  end

  describe "#do" do
    let(:user) { create(:user) }
    let(:project) { create(:project) }
    let!(:user_project_preference) do
      create(:user_project_preference,
             roles: ['collaborator'],
             project: project,
             user: user)
    end

    let(:test_proc) { proc { true } }

    it 'should be allowed to update the resource' do
      result = user.do(:update).to(project).call &test_proc
      expect(result).to be_truthy
    end

    it 'should be allowed to show the resource' do
      result = user.do(:show).to(project).call &test_proc
      expect(result).to be_truthy
    end

    it 'should not be allowed to destroy the resource' do
      user_project_preference.roles = []
      user_project_preference.save!
      expect{user.do(:destroy).to(project).call &test_proc}.to raise_error(ControlControl::AccessDenied)
    end
  end
end

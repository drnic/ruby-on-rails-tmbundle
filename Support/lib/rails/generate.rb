class Generator
  @@list = []
  attr_accessor :name, :default_answer

  def initialize(name, default_answer = "")
    @name, @default_answer = name, default_answer
  end
  
  def question
    @question || begin
      FileUtils.chdir(RailsPath.new.rails_root) do
        output = ruby "script/generate #{name}"
        output =~ /^(Usage.*)$/
        @question = $1 || "Arguments for #{name} generator:"
      end
    end
    @question
  end

  def self.[](name, default_answer = "")
    g = new(name, default_answer)
  end

  def self.setup
    known_generator_names = known_generators.map { |gen| gen.name }
    new_generator_names = find_generator_names - known_generator_names
    @@list = known_generators + new_generator_names.map do |name|
      Generator[name]
    end
  end

  # Collect the names from each generator
  def self.names
    @@list.map { |g| g.name }
  end

  def self.generators
    @@list
  end

  # Runs the script/generate command and extracts generator names from output
  # As of rails 2.3 the parseable script/generate output looks like:
  #
  #   Installed Generators
  #     User: app_layout, check_migration_version, database_yml_mysql, deploy, home_route
  #     Rubygems: jekyll, action_mailer_tls, acts_as_taggable_on_migration, authenticated, cucumber, culerity, delayed_job, email_spec, facebook, facebook_controller, facebook_publisher, facebook_scaffold, feature, form, formtastic, formtastic_stylesheets, install_rubigen_scripts, integration_spec, javascript_test, livedate_jquery, livedate_prototype, publisher, rspec, rspec_controller, rspec_model, rspec_scaffold, scaffold_resource, session, twitter_auth, uploader, xd_receiver
  #     Builtin: controller, helper, integration_test, mailer, metal, migration, model, observer, performance_test, plugin, resource, scaffold, session_migration
  def self.find_generator_names
    list = nil
    FileUtils.chdir(RailsPath.new.rails_root) do
      output = ruby 'script/generate | grep "^  [A-Z]" | sed -e "s/  \w+:\s//"'
      list = output.split(/[,\s]+/).reject {|f| f =~ /:/ || f == "" }
    end
    list
  end

  def self.known_generators
    [
      Generator["scaffold",   "User"],
      Generator["controller", "admin/user_accounts"],
      Generator["model",      "User"],
      Generator["mailer",     "Notify"],
      Generator["migration",  "CreateUserTable"],
      Generator["plugin",     "ActsAsPlugin"]
    ]
  end
end

class UserController < ApplicationController
  layout :choose_layout
  before_filter :login_required, :except => [:forgot_password, :login, :set_new_password, :reset_password]
  before_filter :only_admin_allowed, :only => [:edit, :create, :index, :edit_privilege]
#  filter_access_to :edit_privilege
  def choose_layout
    return 'login' if action_name == 'login' or action_name == 'set_new_password'
    return 'forgotpw' if action_name == 'forgot_password'
    return 'dashboard' if action_name == 'dashboard'
    'application'
  end
  
  def all
    @users = User.all
  end
  
  def list_user
    if params[:user_type] == 'Admin'
      @users = User.find(:all, :conditions => {:admin => true}, :order => 'first_name ASC')
      render(:update) do |page|
        page.replace_html 'users', :partial=> 'users'
        page.replace_html 'employee_user', :text => ''
        page.replace_html 'student_user', :text => ''
      end
    elsif params[:user_type] == 'Employee'
      render(:update) do |page|
        hr = Configuration.find_by_config_value("HR")
        unless hr.nil?
          page.replace_html 'employee_user', :partial=> 'employee_user'
          page.replace_html 'users', :text => ''
          page.replace_html 'student_user', :text => ''
        else
          @users = User.find_all_by_employee(1)
          page.replace_html 'users', :partial=> 'users'
          page.replace_html 'employee_user', :text => ''
          page.replace_html 'student_user', :text => ''
        end
      end
    elsif params[:user_type] == 'Student'
      render(:update) do |page|
        page.replace_html 'student_user', :partial=> 'student_user'
        page.replace_html 'users', :text => ''
        page.replace_html 'employee_user', :text => ''
      end
    elsif params[:user_type] == ''
      @users = ""
      render(:update) do |page|
        page.replace_html 'users', :partial=> 'users'
        page.replace_html 'employee_user', :text => ''
        page.replace_html 'student_user', :text => ''
      end
    end
  end

  def list_employee_user
    emp_dept = params[:dept_id]
    @employee = Employee.find_all_by_employee_department_id(emp_dept, :order =>'first_name ASC')
    @users = @employee.collect { |employee| employee.user}
    @users.delete(nil)
    render(:update) {|page| page.replace_html 'users', :partial=> 'users'}
  end

  def list_student_user
    batch = params[:batch_id]
    @student = Student.find_all_by_batch_id(batch, :conditions => { :is_active => true },:order =>'first_name ASC')
    @users = @student.collect { |student| student.user}
    @users.delete(nil)
    render(:update) {|page| page.replace_html 'users', :partial=> 'users'}
  end

  def change_password
    
    if request.post?
      @user = current_user
      if User.authenticate?(@user.username, params[:user][:old_password])
        if params[:user][:new_password] == params[:user][:confirm_password]
          @user.password = params[:user][:new_password]
          @user.update_attributes(:password => @user.password,
            :role => @user.role_name
          )
          flash[:notice] = t('app.controllers.user_controller.password_changed_successfully')
          redirect_to :action => 'dashboard'
        else
          flash[:warn_notice] = '<p>' + t('app.controllers.user_controller.password_confirmation_failed_please_try_again') + '</p>'
        end
      else
        flash[:warn_notice] = '<p>' + t('app.controllers.user_controller.the_old_password_you_entered_is_incorrect_please_enter_valid_password') + '</p>'
      end
    end
  end

  def user_change_password
    user = User.find_by_username(params[:id])

    if request.post?
      if params[:user][:new_password]=='' and params[:user][:confirm_password]==''
        flash[:warn_notice]= "<p>" + t('app.controllers.user_controller.password_fields_cannot_be_blank') + "</p>"
      else
        if params[:user][:new_password] == params[:user][:confirm_password]
          user.password = params[:user][:new_password]
          user.update_attributes(:password => user.password,
            :role => user.role_name
          )
          flash[:notice]= t('app.controllers.user_controller.password_has_been_updated_successfully')
          redirect_to :action=>"edit", :id=>user.username
        else
          flash[:warn_notice] = '<p>' + t('app.controllers.user_controller.password_confirmation_failed_please_try_again') + '</p>'
        end
      end

      
    end
  end

  def create
    @config = Configuration.available_modules

    @user = User.new(params[:user])
    if request.post?
      if @user.save
        if @config.include?('HR')
          @employee = Employee.new
          @employee.first_name =  @user.first_name
          @employee.last_name =  @user.last_name
          @employee.employee_number =  @user.username
          @employee.employee_number =  @user.username
          @employee.employee_category_id =  1
          @employee.employee_position_id =  1
          @employee.employee_department_id =  1
          @employee.employee_grade_id =  1
          @employee.date_of_birth =  Date.today - 20.year
          @employee.joining_date =  Date.today - 5.year
          @employee.save
        end
        flash[:notice] = t('app.controllers.user_controller.user_account_created')
        redirect_to :controller => 'user', :action => 'edit', :id => @user.username
      else
        flash[:notice] = t('app.controllers.user_controller.user_account_not_created')
      end
    end
  end

  def delete
    @user = User.find_by_username(params[:id]).destroy
    flash[:notice] = t('app.controllers.user_controller.user_account_deleted')
    redirect_to :controller => 'user'
  end

  def dashboard
    @user = current_user
    #@reminders = @users.check_reminders
    @config = Configuration.available_modules
    @employee = Employee.find_by_employee_number(@user.username)
    @employee ||= Employee.first if current_user.admin?
    @student = Student.find_by_admission_no(@user.username)
  end

  def edit
    @user = User.find_by_username(params[:id])
    @current_user = current_user
    if request.post? and @user.update_attributes(params[:user])
      flash[:notice] = t('app.controllers.user_controller.user_account_updated')
      redirect_to :controller => 'user', :action => 'profile', :id => @user.username
    end
  end

  def forgot_password
#    flash[:notice]= t('app.controllers.user_controller.you_do_not_have_permission_to_access_forgot_password')
#    redirect_to :action=>"login"
  
    if request.post? and params[:reset_password]
      if user = User.find_by_email(params[:reset_password][:email])
        user.reset_password_code = Digest::SHA1.hexdigest( "#{user.email}#{Time.now.to_s.split(//).sort_by {rand}.join}" )
        user.reset_password_code_until = 1.day.from_now
        user.role = user.role_name
        user.save(false)
        UserNotifier.deliver_forgot_password(user)
        flash[:notice] = t('app.controllers.user_controller.reset_password_link_emailed_to') + "#{user.email}"
        redirect_to :action => "index"
      else
        flash[:notice] = t('app.controllers.user_controller.no_user_exists_with_email_address') + "#{params[:reset_password][:email]}"
      end
    end
  end

  def login
    @institute = Configuration.find_by_config_key("LogoName")
    if request.post? and params[:user]
      @user = User.new(params[:user])
      user = User.find_by_username @user.username
      if user and User.authenticate?(@user.username, @user.password)
        session[:user_id] = user.id
        flash[:notice] = t('app.controllers.user_controller.welcome') + ", #{user.first_name} #{user.last_name}!"
        redirect_to :controller => 'user', :action => 'dashboard'
      else
        flash[:notice] = t('app.controllers.user_controller.invalid_username_or_password_combination')
      end
    end
  end

  def logout
    session[:user_id] = nil
    flash[:notice] = t('app.controllers.user_controller.logged_out')
    redirect_to :controller => 'user', :action => 'login'
  end

  def profile
    @config = Configuration.available_modules
    @current_user = current_user
    @username = @current_user.username if session[:user_id]
    @user = User.find_by_username(params[:id])
    @employee = Employee.find_by_employee_number(@user.username)
    @student = Student.find_by_admission_no(@user.username)
    if @user.nil?
      flash[:notice] = t('app.controllers.user_controller.user_profile_not_found')
      redirect_to :action => 'dashboard'
    end
  end

  def reset_password
    user = User.find_by_reset_password_code(params[:id])
    if user
      if user.reset_password_code_until > Time.now
        redirect_to :action => 'set_new_password', :id => user.reset_password_code
      else
        flash[:notice] = t('app.controllers.user_controller.reset_time_expired')
        redirect_to :action => 'index'
      end
    else
      flash[:notice]= t('app.controllers.user_controller.invalid_reset_link')
      redirect_to :action => 'index'
    end
  end

  def search_user_ajax
    unless params[:query].nil? or params[:query].empty? or params[:query] == ' '
      @user = User.first_name_or_last_name_or_username_like_any params[:query].split
    else
      @user = ''
    end
    render :layout => false
  end

  def set_new_password
    if request.post?
      user = User.find_by_reset_password_code(params[:id])
      if user
        if params[:set_new_password][:new_password] === params[:set_new_password][:confirm_password]
          user.password = params[:set_new_password][:new_password]
          user.update_attributes(:password => user.password, :reset_password_code => nil, :reset_password_code_until => nil, :role => user.role_name)
          #User.update(user.id, :password => params[:set_new_password][:new_password],
           # :reset_password_code => nil, :reset_password_code_until => nil)
          flash[:notice] = t('app.controllers.user_controller.password_succesfully_reset_use_new_password_to_log_in')
          redirect_to :action => 'index'
        else
          flash[:notice] = t('app.controllers.user_controller.password_confirmation_failed_please_enter_password_again')
          redirect_to :action => 'set_new_password', :id => user.reset_password_code
        end
      else
        flash[:notice] = t('app.controllers.user_controller.you_have_followed_an_invalid_link_please_try_again')
        redirect_to :action => 'index'
      end
    end
  end

  def edit_privilege
    @privileges = Privilege.find(:all)
    @user = User.find_by_username(params[:id])
    if request.post?
      new_privileges = params[:user][:privilege_ids] if params[:user]
      new_privileges ||= []
      @user.privileges = Privilege.find_all_by_id(new_privileges)

      flash[:notice] = t('app.controllers.user_controller.role_updated')
      redirect_to :action => 'profile',:id => @user.username
    end
  end

  def header_link
   @user = current_user
    #@reminders = @users.check_reminders
    @config = Configuration.available_modules
    @employee = Employee.find_by_employee_number(@user.username)
    @employee ||= Employee.first if current_user.admin?
    @student = Student.find_by_admission_no(@user.username)
    render :partial=>'header_link'
end
end


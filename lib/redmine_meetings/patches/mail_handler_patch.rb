require_dependency 'mail_handler'

module MeetingMailHandlerPatch
  def self.included(base) # :nodoc:
    base.extend(MeetingMailHandlerClassMethods)

    base.send(:include, MeetingMailHandlerInstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      class << self
        # I dislike alias method chain, it's not the most readable backtraces

      end

    end

  end

  module MeetingMailHandlerClassMethods

  end

  module MeetingMailHandlerInstanceMethods
    
    private 
    
    def receive_meeting_doodle_reply(doodle_id)
      doodle = MeetingDoodle.find(doodle_id, :include => [:project, :author, :responses])
      project = doodle.project
      sender_email = email.from.to_a.first.to_s.strip
      if User.current.allowed_to?(:answer_doodle, project) && User.current.mail
        response = doodle.responses.find_or_initialize_by_author_id(User.current.id)
        name = User.current.name
      else
        emails = doodle.tab_emails
        found = false
        if (!emails.nil?) && (!emails.empty?)
          emails.each do |em|
            if em.strip.casecmp(sender_email) == 0
              name = sender_email
              response = doodle.responses.find_or_initialize_by_name(name)
              response.author = User.anonymous
              found = true
            end
          end
        end
        if !found
          raise MailHandler::UnauthorizedAction
        end
      end

      body = plain_text_body
      if !(body.match(/^.*-----------BEGIN-------------------/m) && body.match(/------------END--------------------.*$/m))
        doodle.deliver_invalid_answer(sender_email, User.current)
      else
        body = body.gsub(/^.*-----------BEGIN-------------------/m, '')
        body = body.gsub(/------------END--------------------.*$/m, '')
        received = body.split(/\n/)
        answers = []
        doodle.tab_options.each do |opt|
          found = false
          received.each do |r|
            if r.strip.end_with?(opt.strip)
              found = true
            end
          end
          answers << found
        end
        response.answers = answers
        response.save
        response.deliver_ak_answer(sender_email, User.current)
      end
      doodle
    end

  end
end

# Add module to MailHandler
MailHandler.send(:include, MeetingMailHandlerPatch)

# frozen_string_literal: true

module GetStream

  module Generated

    class ChatClient

      # The generated name of the fork message map method changes from fork_message_i_ds to
      # fork_message_ids in a later regeneration. Keep both names working on either side of it.
      if method_defined?(:fork_message_i_ds) && !method_defined?(:fork_message_ids)
        alias fork_message_ids fork_message_i_ds
      elsif method_defined?(:fork_message_ids) && !method_defined?(:fork_message_i_ds)
        # @deprecated Use {#fork_message_ids} instead.
        alias fork_message_i_ds fork_message_ids
      end

    end

  end

end

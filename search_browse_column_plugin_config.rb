module SearchAndBrowseColumnPlugin
  def self.config
    {
      'event' => {
        # you can add columns that are not options by default by adding an entry for them in this hash
        # minimally it should have colmun name => {:field => column name} but you can also add additonal options like sortable
        :add => {
          'outcome_note' => {:field => 'outcome_note'}
        }
      }
    }
  end
end

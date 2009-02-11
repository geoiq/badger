require 'java'
class BadgerUI < javax.swing.JFrame
  include java.awt.event.ActionListener
  def initialize
    super("Badger - Finder Batch Uploader")
    self.setDefaultCloseOperation(javax.swing.JFrame::EXIT_ON_CLOSE)
    #self.setResizable(false)
    self.setSize(350,200)
    
    # configure the nested layout
    outer_layout = java.awt.BorderLayout.new(10, 10)
    inner_layout = java.awt.GridLayout.new(5,2)
    self.getContentPane.setLayout(outer_layout)
    inner = javax.swing.JPanel.new(inner_layout)
    self.getContentPane.add(inner, java.awt.BorderLayout::CENTER)
    
    # add controls
    inner.add(javax.swing.JLabel.new("Login: "))
    @login_field = javax.swing.JTextField.new
    inner.add(@login_field)
    inner.add(javax.swing.JLabel.new("Password: "))
    @password_field = javax.swing.JPasswordField.new
    inner.add(@password_field)
    inner.add(javax.swing.JLabel.new("Finder URL: "))
    @url_field = javax.swing.JTextField.new
    inner.add(@url_field)
    inner.add(javax.swing.JLabel.new("Data Folder: "))
    @data_field = javax.swing.JLabel.new(File.expand_path("#{File.dirname(__FILE__).sub(/^file:/,'').sub(/badger\.jar\!\/f1$/, '')}/data"))
    inner.add(@data_field)
    inner.add(javax.swing.JPanel.new)
    
    @upload_button = javax.swing.JButton.new("Upload")
    @upload_button.addActionListener(self)
    inner.add(@upload_button)
    
    # add spacers
    self.getContentPane.add(javax.swing.JPanel.new, java.awt.BorderLayout::EAST)
    self.getContentPane.add(javax.swing.JPanel.new, java.awt.BorderLayout::WEST)
    self.getContentPane.add(javax.swing.JPanel.new, java.awt.BorderLayout::NORTH)
    @progress = javax.swing.JProgressBar.new
    self.getContentPane.add(@progress, java.awt.BorderLayout::SOUTH)
    
    self.show
  end
  
  def actionPerformed(ae)
    @upload_button.setEnabled(false)
    unless @url_field.getText =~ /^http:\/\/finder\./
      raise ArgumentError, "URL should be of the form: http://finder.something"
    end
    b = Badger.new(@url_field.getText,
               @login_field.getText,
               @password_field.getText)
    files = Dir.glob(@data_field.getText.gsub(/\/$/,'') + "/*.xml")
    @progress.setMinimum(0); @progress.setMaximum(files.length)
    @progress.setString("processing"); @progress.setStringPainted(true)
    current = 1
    Thread.start do
      files.each do |f|
        begin
          b.process(f.sub(/\.xml$/, ''))
          Thread.pass
        rescue Exception => e
          show_error(e.message)
          puts "Failure: #{f}"
          next
        ensure
          @progress.setValue(current+=1)
        end
      end.join
      @progress.setString("done"); @progress.setValue(0)
      @upload_button.setEnabled(true)
      show_message("Your batch upload is complete")
    end
  rescue Exception => e
    show_error(e.message)
    @upload_button.setEnabled(true)
  end
  
  def show_message(content)
    javax.swing.JOptionPane.showMessageDialog(self, content, "Badger Says", javax.swing.JOptionPane::INFORMATION_MESSAGE)    
  end
  
  def show_error(content)
    javax.swing.JOptionPane.showMessageDialog(self, content, "Badger Says", javax.swing.JOptionPane::ERROR_MESSAGE)
  end
end
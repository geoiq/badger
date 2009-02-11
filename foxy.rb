#!/usr/bin/env ruby

%w{ rubygems fox16 fox16/colors yaml }.each {|gem| require gem}

include Fox

BLURB = <<END
GeoCommons Badger uploader!
END

class DataTargetWindow < FXMainWindow
  def initialize(app)
    # Initialize base class
    super(app, "GeoCommons Foxy Badger!", :opts => DECOR_ALL, :x => 20, :y => 20, :width => 700, :height => 460)

    # Create a data target with an integer value
    @intTarget = FXDataTarget.new(0)

    @user = FXDataTarget.new("admin")

    # Create a data target with a floating point value
    @password = FXDataTarget.new("password")

    # Create a data target with a string value
    @finder = FXDataTarget.new("http://finder.local")

    # Create a data target with a color value
    @dataDirectory = FXDataTarget.new("data")

   # Create another integer data target to track the "progress"
    @progressTarget = FXDataTarget.new(0)
    
    
    # Menubar
    menubar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
    
    # File menu
    filemenu = FXMenuPane.new(self)
    FXMenuCommand.new(filemenu, "&Quit\tCtl-Q", nil, getApp(), FXApp::ID_QUIT)
    FXMenuTitle.new(menubar, "&File", nil, filemenu)

    # Lone progress bar at the bottom
    FXProgressBar.new(self, @progressTarget, FXDataTarget::ID_VALUE,
      LAYOUT_SIDE_BOTTOM|LAYOUT_FILL_X|FRAME_SUNKEN|FRAME_THICK)

    FXHorizontalSeparator.new(self,
      LAYOUT_SIDE_TOP|SEPARATOR_GROOVE|LAYOUT_FILL_X)

    horframe = FXHorizontalFrame.new(self, LAYOUT_SIDE_TOP | LAYOUT_FILL_X)
    FXLabel.new(horframe, BLURB, nil, LAYOUT_SIDE_TOP | JUSTIFY_LEFT)

    FXHorizontalSeparator.new(self,
      LAYOUT_SIDE_TOP|SEPARATOR_GROOVE|LAYOUT_FILL_X)

    # Arrange nicely
    infoFrame = FXHorizontalFrame.new(self, LAYOUT_FILL_X|LAYOUT_FILL_Y)
    infoMatrix = FXMatrix.new(infoFrame, 2, MATRIX_BY_COLUMNS|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    FXLabel.new(infoMatrix, "Username:")
    FXTextField.new(infoMatrix, 20, @user, FXDataTarget::ID_VALUE, TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(infoMatrix, "Password:")
    FXTextField.new(infoMatrix, 20, @password, FXDataTarget::ID_VALUE, TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(infoMatrix, "Finder url:")
    FXTextField.new(infoMatrix, 20, @finder, FXDataTarget::ID_VALUE, TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(infoMatrix, "Data directory:")
    FXTextField.new(infoMatrix, 20, @dataDirectory, FXDataTarget::ID_VALUE, TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)

    btn = FXButton.new(infoMatrix, "Upload", :opts => BUTTON_NORMAL|LAYOUT_RIGHT)
    btn.connect(SEL_COMMAND) do
      File.open("geocommons.yml", "w") do |file|
        file << {:user => @user.to_s, :pass => @password.to_s, :finder => @finder.to_s, :data => @dataDirectory.to_s}.to_yaml
      end
      # Kick off the timer
      getApp().addTimeout(80, method(:onTimeout))
    end
    
    @status = FXText.new(infoMatrix, :opts => TEXT_READONLY|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    
    
    # Install an accelerator
    self.accelTable.addAccel(fxparseAccel("Ctl-Q"), getApp(), FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
  end

  # Timer expired; update the progress
  def onTimeout(sender, sel, ptr)
    # Increment the progress modulo 100
    @progressTarget.value = (@progressTarget.value + 1) % 100

    # # Reset the timer for next time
    getApp().addTimeout(80, method(:onTimeout))
  end

    # Quit
    def onCmdQuit(sender, sel, ptr)
      getApp.exit(0)
    end

  # Start
  def create
    # Create window
    super

    # Show the main window
    show(PLACEMENT_SCREEN)
  end
end

if __FILE__ == $0
  # Make an application
  application = FXApp.new("GeoCommons Badger", "GeoCommons Badger")

  # Current threads implementation causes problems for this example, so disable
  application.threadsEnabled = false

  # Create main window
  window = DataTargetWindow.new(application)

  # Handle interrupts to quit application gracefully
  application.addSignal("SIGINT", window.method(:onCmdQuit))

  # Create the application
  application.create

  # Run
  application.run
end
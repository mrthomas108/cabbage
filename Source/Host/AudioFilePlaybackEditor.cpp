/*
  Copyright (c) 2015 - Rory Walsh

  Cabbage is free software; you can redistribute it
  and/or modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  Cabbage is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with Csound; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
  02111-1307 USA
*/

#include "AudioFilePlaybackProcessor.h"
#include "AudioFilePlaybackEditor.h"

#define BUTTON_SIZE 25
WaveformDisplay::WaveformDisplay(AudioFormatManager& formatManager, BufferingAudioSource *source, int sr, Colour col):
thumbnailCache(15),
thumbnail (16, formatManager, thumbnailCache),
source(source),
tableColour(col),
sampleRate(sr),
scrollbar(false),
currentPlayPosition(0)
{
    thumbnail.addChangeListener(this);
    currentPositionMarker.setFill (Colours::lime);
    addAndMakeVisible(currentPositionMarker);
    addAndMakeVisible (scrollbar);
    scrollbar.setRangeLimits (visibleRange);
    scrollbar.setAutoHide (false);
    scrollbar.addListener (this);
}

WaveformDisplay::~WaveformDisplay()
{
    stopTimer();
}

void WaveformDisplay::resized()
{
    scrollbar.setBounds (getLocalBounds().removeFromBottom (20).reduced (2));
}

void WaveformDisplay::setScrubberPos(double pos)
{
    currentPositionMarker.setVisible (true);
    //pos = (pos/(thumbnail.getTotalLength()*sampleRate))*thumbnail.getTotalLength();
    currentPositionMarker.setRectangle (Rectangle<float> (timeToX (pos) - 0.75f, 0,
                                                          1.5f, (float) (getHeight() - scrollbar.getHeight())));
}

void WaveformDisplay::changeListenerCallback (ChangeBroadcaster*)
{
    repaint();
}

void WaveformDisplay::setFile (const File& file)
{
    AudioFormatManager format;
    format.registerBasicFormats();
    AudioFormatReader* reader = format.createReaderFor(file);
    
    if(reader)
    {
        AudioSampleBuffer buffer(reader->numChannels, reader->lengthInSamples);
        buffer.clear();
        buffer.setSize(reader->numChannels, reader->lengthInSamples);
        reader->read(&buffer,0, buffer.getNumSamples(), 0, true, true);
        setWaveform(buffer, reader->numChannels);
    }
    
    delete reader;
}

void WaveformDisplay::setWaveform(AudioSampleBuffer buffer, int channels)
{
    thumbnail.clear();
    thumbnail.reset(channels, 44100, buffer.getNumSamples());
    thumbnail.addBlock(0, buffer, 0, buffer.getNumSamples());
    const Range<double> newRange (0.0, thumbnail.getTotalLength());
    scrollbar.setRangeLimits (newRange);
    setRange (newRange);
}

void WaveformDisplay::setZoomFactor (double amount)
{
    if (thumbnail.getTotalLength() > 0)
    {
        const double newScale = jmax (0.001, thumbnail.getTotalLength() * (1.0 - jlimit (0.0, 0.99, amount)));
        const double timeAtCentre = xToTime (getWidth() / 2.0f);
        setRange (Range<double> (timeAtCentre - newScale * 0.5, timeAtCentre + newScale * 0.5));
    }
}

void WaveformDisplay::setRange (Range<double> newRange)
{
    visibleRange = newRange;
    scrollbar.setCurrentRange (visibleRange);
    repaint();
}

void WaveformDisplay::paint (Graphics& g)
{
    g.fillAll (Colour(20, 20, 20));
    g.setColour (tableColour);
    
    
    
    if (thumbnail.getTotalLength() > 0)
    {
        Rectangle<int> thumbArea (getLocalBounds());
        thumbArea.removeFromBottom (scrollbar.getHeight() + 4);
        thumbnail.drawChannels (g, thumbArea.reduced (2),
                                visibleRange.getStart(), visibleRange.getEnd(), 1.0f);
    }
    else
    {
        g.setFont (14.0f);
        g.drawFittedText ("(No audio file selected)", getLocalBounds(), Justification::centred, 2);
    }
    
}

void WaveformDisplay::timerCallback()
{
    if(thumbnail.getTotalLength()>0)
    {
        currentPlayPosition = source->getNextReadPosition()/sampleRate;
        setScrubberPos(currentPlayPosition);
    }
}

void WaveformDisplay::mouseDown (const MouseEvent& e)
{
    if(thumbnail.getTotalLength()>0)
    {
        source->setNextReadPosition (jmax (0.0, xToTime ((float) e.x)*sampleRate));
        currentPlayPosition = jmax (0.0, xToTime ((float) e.x));
        setScrubberPos(currentPlayPosition);
    }
}

void WaveformDisplay::mouseDrag (const MouseEvent& e)
{
    if(thumbnail.getTotalLength()>0)
    {
        source->setNextReadPosition (jmax (0.0, xToTime ((float) e.x)*sampleRate));
        currentPlayPosition = jmax (0.0, xToTime ((float) e.x));
        setScrubberPos(currentPlayPosition);
    }
}

void WaveformDisplay::resetPlaybackPosition()
{
    currentPlayPosition=0;
}

float WaveformDisplay::timeToX (const double time) const
{
    return getWidth() * (float) ((time - visibleRange.getStart()) / (visibleRange.getLength()));
}

double WaveformDisplay::xToTime (const float x) const
{
    return (x / getWidth()) * (visibleRange.getLength()) + visibleRange.getStart();
}

void WaveformDisplay::scrollBarMoved (ScrollBar* scrollBarThatHasMoved, double newRangeStart)
{
    if (scrollBarThatHasMoved == &scrollbar)
        setRange (visibleRange.movedToStartAt (newRangeStart));
}



//==============================================================================
AudioFilePlaybackEditor::AudioFilePlaybackEditor (AudioFilePlaybackProcessor* ownerFilter):
AudioProcessorEditor (ownerFilter),
playButton("playButton", DrawableButton::ImageOnButtonBackground),
stopButton("stopButton", DrawableButton::ImageOnButtonBackground),
openButton("openButton", DrawableButton::ImageOnButtonBackground),
zoomInButton("zoomInButton", DrawableButton::ImageOnButtonBackground),
zoomOutButton("zoomOutButton", DrawableButton::ImageOnButtonBackground),
basicLook(),
zoom(0)
{
    AudioFormatManager formatManager;
    formatManager.registerBasicFormats();
    
    tableColour = Colour(Random::getSystemRandom().nextInt(255),
                         Random::getSystemRandom().nextInt(255),
                         Random::getSystemRandom().nextInt(255));
    
	waveformDisplay = new WaveformDisplay(formatManager, getFilter()->bufferingAudioFileSource, getFilter()->sourceSampleRate, tableColour);
	setOpaque(false);
	playButton.addListener(this);
	addAndMakeVisible(&playButton);
	stopButton.addListener(this);
	addAndMakeVisible(&stopButton);
	openButton.addListener(this);
	addAndMakeVisible(&openButton);
	zoomInButton.addListener(this);
	addAndMakeVisible(&zoomInButton);
	zoomOutButton.addListener(this);
	addAndMakeVisible(&zoomOutButton);	

	playButton.setLookAndFeel(&basicLook);
	stopButton.setLookAndFeel(&basicLook);
	openButton.setLookAndFeel(&basicLook);
	zoomOutButton.setLookAndFeel(&basicLook);
	zoomInButton.setLookAndFeel(&basicLook);
	
	zoomOutButton.getProperties().set("isRounded", true);
	zoomInButton.getProperties().set("isRounded", true);
	
	openButton.setColour(TextButton::buttonColourId, Colours::white);	
	playButton.setColour(TextButton::buttonColourId, Colours::white);
	playButton.setColour(TextButton::buttonOnColourId, Colours::yellow);
	zoomOutButton.setColour(TextButton::buttonColourId, Colours::white);
	zoomInButton.setColour(TextButton::buttonColourId, Colours::white);
	
	playButton.setClickingTogglesState(true);	
	
	stopButton.setColour(TextButton::buttonColourId, Colours::white);	
	
	playButton.setImages(cUtils::createPlayButtonPath(25), 
						 cUtils::createPlayButtonPath(25), 
						 cUtils::createPauseButtonPath(25), 
						 cUtils::createPlayButtonPath(25), 
						 cUtils::createPauseButtonPath(25));

	openButton.setImages(cUtils::createOpenButtonPath(25));		
	stopButton.setImages(cUtils::createStopButtonPath(25));
	
	zoomInButton.setImages(cUtils::createZoomInButtonPath(25));
	zoomOutButton.setImages(cUtils::createZoomOutButtonPath(25));
	//waveformDisplay->setBounds(10, 10, 500, 200);
	addAndMakeVisible(waveformDisplay);
    setSize (500, 250);

	if(File(getFilter()->getCurrentFile()).existsAsFile())
		waveformDisplay->setFile(File(getFilter()->getCurrentFile()));


}

AudioFilePlaybackEditor::~AudioFilePlaybackEditor()
{
    getFilter()->editorBeingDeleted(this);
	waveformDisplay->stopTimer();
}

//==============================================================================
void AudioFilePlaybackEditor::resized()
{
	waveformDisplay->setBounds(BUTTON_SIZE+7, 5, getWidth()-(BUTTON_SIZE+12), getHeight()-14);
	//viewport->setBounds(BUTTON_SIZE+7, 5, getWidth()-20, getHeight()-10);	
	stopButton.setBounds(3, 5, BUTTON_SIZE, BUTTON_SIZE);
	playButton.setBounds(3, BUTTON_SIZE+5, BUTTON_SIZE, BUTTON_SIZE);
	openButton.setBounds(3, ((BUTTON_SIZE)*2)+5, BUTTON_SIZE, BUTTON_SIZE);
	zoomInButton.setBounds(3, ((BUTTON_SIZE)*3)+5, BUTTON_SIZE, BUTTON_SIZE);
	zoomOutButton.setBounds(3, ((BUTTON_SIZE)*4)+5, BUTTON_SIZE, BUTTON_SIZE);
}
//==============================================================================
void AudioFilePlaybackEditor::paint (Graphics& g)
{
	g.fillAll(Colours::black);
    g.setColour(tableColour);
    g.drawRect(0, 0, getWidth(), getHeight());
}
//==============================================================================
void AudioFilePlaybackEditor::itemDropped (const DragAndDropTarget::SourceDetails& dragSourceDetails)
{
	if(FileTreeComponent* fileComp = dynamic_cast<FileTreeComponent*>(dragSourceDetails.sourceComponent.get()))			
	{
		getFilter()->setupAudioFile(fileComp->getSelectedFile());
		getFilter()->prepareToPlay(0, 512);
		if(getFilter()->bufferingAudioFileSource)
		{
			waveformDisplay->source = getFilter()->bufferingAudioFileSource;
			waveformDisplay->setFile(fileComp->getSelectedFile());	
		}	
	}
}
	
//==============================================================================
void AudioFilePlaybackEditor::buttonClicked(Button *button)
{
	
	if(button->getName()=="playButton")
	{
		if(getFilter()->bufferingAudioFileSource)
		{
			if(!getFilter()->isSourcePlaying)
				waveformDisplay->startTimer(10);
			else
				waveformDisplay->stopTimer();

			getFilter()->isSourcePlaying=!getFilter()->isSourcePlaying;			
		}
	}

    else if(button->getName()=="zoomInButton")
    {
        zoom=jmin(1.0, zoom+.1);
        
        waveformDisplay->setZoomFactor(zoom);
    }
    
    else if(button->getName()=="zoomOutButton")
    {
        zoom=jmin(0.0, zoom-.1);
        waveformDisplay->setZoomFactor(zoom);
    }
    
	else if(button->getName()=="stopButton")
	{
		if(getFilter()->bufferingAudioFileSource)
		{
			playButton.setToggleState(false, dontSendNotification);
			waveformDisplay->stopTimer();
			getFilter()->isSourcePlaying=false;
			waveformDisplay->resetPlaybackPosition();
			getFilter()->bufferingAudioFileSource->setNextReadPosition(0);	
		}	
	}
	
	else if(button->getName()=="openButton")
	{
	    FileChooser fc ("Open file");

	    if (fc.browseForFileToOpen())
		{
			getFilter()->setupAudioFile(fc.getResult());
			getFilter()->prepareToPlay(0, 512);
			if(getFilter()->bufferingAudioFileSource)
			{
				waveformDisplay->source = getFilter()->bufferingAudioFileSource;
				waveformDisplay->setFile(fc.getResult());	
			}
					
			//waveformDisplay->setZoomFactor(1);
		}	
	}
			

}

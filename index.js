// JavaScript

import React from 'react';
import requireNativeComponent from 'react-native';

const VideoPlayerView = requireNativeComponent('VideoPlayerView', VideoPlayer);

export default class VideoPlayer extends React.Component {
  static propTypes = {
    url: React.PropTypes.string
  };

  render() {
    return <VideoPlayerView {...this.props} />;
  }
}

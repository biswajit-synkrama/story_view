import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_video_player/cached_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

import '../controller/story_controller.dart';
import '../utils/utils.dart';

class VideoLoader {
  String url;
  String storyIndex;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, this.storyIndex, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream = DefaultCacheManager().getFileStream(this.url,
        headers: this.requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController storyController;
  final VideoLoader videoLoader;
  final bool isHLS;
  final bool isRepost;
  final bool isLike;
  final VoidCallback viewPost;
  final String userName;
  final String userProfile;
  final BoxFit fit;

  StoryVideo(this.videoLoader,
      {required this.storyController,
      this.isHLS = false,
      required this.isRepost,
      required this.isLike,
      required this.viewPost,
      required this.fit,
      this.userName = "",
      this.userProfile = "",
      Key? key})
      : super(key: key ?? UniqueKey());

  static StoryVideo url(String url, String storyId,
      {required StoryController controller,
      required bool isHLS,
      required bool isRepost,
      required bool isLike,
      required VoidCallback viewPost,
      String? userName,
      String? userProfile,
      Map<String, dynamic>? requestHeaders,
      BoxFit fit = BoxFit.fitWidth,
      Key? key}) {
    return StoryVideo(
      VideoLoader(url, storyId, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
      isHLS: isHLS,
      isRepost: isRepost,
      isLike: isLike,
      viewPost: viewPost,
      fit: fit,
      userName: userName ?? "",
      userProfile: userProfile ?? "",
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  //bool
  bool isVideoLoaded = false;

  CachedVideoPlayerController playerController =
      CachedVideoPlayerController.network("");

  var secondRandomColor =
      Color((math.Random().nextDouble() * 0x000000).toInt()).withOpacity(0.1);

  var firstRandomColor =
      Color((math.Random().nextDouble() * 0x0F0F0F).toInt()).withOpacity(0.2);

  @override
  void initState() {
    super.initState();

    widget.storyController.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        /// if video is HLS, need to load it from network, if is a downloaded file, need to load it from local cache
        if (widget.isHLS == true) {
          this.playerController =
              CachedVideoPlayerController.network(widget.videoLoader.url);
        } else {
          this.playerController =
              CachedVideoPlayerController.file(widget.videoLoader.videoFile!);
        }
        this.playerController.initialize().then((v) {
          setState(() {});
          widget.storyController.play();
        });

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController.pause();
            } else {
              playerController.play();
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        playerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: widget.isRepost == true
            ? Center(
              child: Stack(
                children: [
                  ClipRect(
                    child: new BackdropFilter(
                      filter: new ImageFilter.blur(
                          sigmaX: 15.0, sigmaY: 15.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                              vertical: 80.0, horizontal: 50.0),
                          child: Container(
                              height: MediaQuery.of(context).size.height * 0.65,
                              width: MediaQuery.of(context).size.width * 0.95,
                              decoration: new BoxDecoration(
                                color: Colors.grey.shade200.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: FittedBox(
                                  fit: widget.fit,
                                  child: SizedBox(
                                    width: playerController.value.aspectRatio,
                                    height: 1,
                                    child: CachedVideoPlayer(playerController),
                                  ),
                                ),
                                // child: AspectRatio(
                                //   aspectRatio:
                                //       playerController.value.aspectRatio,
                                //   child: CachedVideoPlayer(playerController),
                                // ),
                              )),
                        ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 50.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            widget.userProfile.isNotEmpty == true
                                ? CircleAvatar(
                                    radius: 18,
                                    backgroundImage:
                                        NetworkImage(widget.userProfile),
                                    backgroundColor: Colors.grey,
                                  )
                                : CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        AssetImage("assets/images/img.png"),
                                    backgroundColor: Colors.grey,
                                  ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  widget.userName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: "NexaBold",
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
            : Center(
                child: FittedBox(
                  fit: widget.fit,
                  child: SizedBox(
                    width: playerController.value.aspectRatio,
                    height: 1,
                    child: CachedVideoPlayer(playerController),
                  ),
                ),
                // child: FittedBox(
                //   fit: widget.fit,
                //   child: AspectRatio(
                //     aspectRatio: playerController.value.aspectRatio,
                //     child: CachedVideoPlayer(playerController),
                //   ),
                // ),
              ),
      );
    }

    return widget.videoLoader.state == LoadState.loading ||
            !playerController.value.isInitialized == true
        ? Shimmer.fromColors(
            baseColor: Color(0xFF222124),
            highlightColor: Colors.grey.withOpacity(0.2),
            child: Container(
              color: Colors.black,
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.grey[500]!,
                  shape: const RoundedRectangleBorder(),
                ),
              ),
            ),
          )
        : Center(
            child: Text(
            "Media failed to load.",
            style: TextStyle(
              color: Colors.white,
            ),
          ));
  }

  @override
  Widget build(BuildContext context) {
    return widget.isRepost == true
        ? Stack(
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaY: 15, sigmaX: 15),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [firstRandomColor, secondRandomColor],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: getContentView(),
                ),
              ),
              widget.videoLoader.state == LoadState.loading ||
                      !playerController.value.isInitialized == true
                  ? Container()
                  : Align(
                      alignment: FractionalOffset.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 120.0),
                        child: InkWell(
                          onTap: () {
                            widget.viewPost();
                          },
                          child: Container(
                            height: 50,
                            width: 120,
                            decoration: new BoxDecoration(
                              color: Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "View Post",
                                    style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: "NexaBold",
                                  fontWeight: FontWeight.w500),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_outlined,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          )
        : Container(
            width: double.infinity,
            height: double.infinity,
            child: getContentView(),
          );
  }

  @override
  void dispose() {
    playerController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}

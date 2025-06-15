import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/theme_provider.dart';

class ImageNetworkWithShimmer extends StatelessWidget {
  final String imageUrl;
  final ThemeProvider themeProvider;
  final double? borderRadius;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool fullView;

  const ImageNetworkWithShimmer({
    super.key,
    required this.imageUrl,
    required this.themeProvider,
    this.borderRadius,
    this.fit,
    this.width,
    this.height,
    this.fullView = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius?.r ?? 12.r),
      child: Container(
        width: fullView ? double.infinity : width,
        height: fullView ? null : height,
        constraints: fullView 
            ? BoxConstraints(
                minHeight: 200.h,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              )
            : null,
        child: Image.network(
          imageUrl,
          width: fullView ? double.infinity : width,
          height: fullView ? null : height,
          fit: fit ?? (fullView ? BoxFit.cover : BoxFit.contain),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            
            return Shimmer.fromColors(
              baseColor: themeProvider.isDarkMode 
                  ? Colors.grey[800]! 
                  : Colors.grey[300]!,
              highlightColor: themeProvider.isDarkMode 
                  ? Colors.grey[700]! 
                  : Colors.grey[100]!,
              child: Container(
                width: fullView ? double.infinity : width ?? double.infinity,
                height: fullView ? 200.h : height ?? 200.h,
                decoration: BoxDecoration(
                  color: themeProvider.secondaryBackgroundColor,
                  borderRadius: BorderRadius.circular(borderRadius?.r ?? 12.r),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      themeProvider.primaryTextColor.withOpacity(0.6),
                    ),
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: fullView ? double.infinity : width ?? double.infinity,
              height: fullView ? 200.h : height ?? 200.h,
              decoration: BoxDecoration(
                color: themeProvider.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(borderRadius?.r ?? 12.r),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: themeProvider.tertiaryTextColor,
                      size: 32.sp,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        color: themeProvider.tertiaryTextColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FullViewImageWidget extends StatelessWidget {
  final String imageUrl;
  final ThemeProvider themeProvider;
  final double? borderRadius;

  const FullViewImageWidget({
    super.key,
    required this.imageUrl,
    required this.themeProvider,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius?.r ?? 15.r),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: isLandscape ? screenSize.height * 0.4 : 200.h,
          maxHeight: isLandscape ? screenSize.height * 0.8 : screenSize.height * 0.6,
        ),
        child: Image.network(
          imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            
            return Container(
              width: double.infinity,
              height: isLandscape ? screenSize.height * 0.4 : 200.h,
              decoration: BoxDecoration(
                color: themeProvider.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(borderRadius?.r ?? 15.r),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Shimmer.fromColors(
                    baseColor: themeProvider.isDarkMode 
                        ? Colors.grey[800]! 
                        : Colors.grey[300]!,
                    highlightColor: themeProvider.isDarkMode 
                        ? Colors.grey[700]! 
                        : Colors.grey[100]!,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: themeProvider.secondaryBackgroundColor,
                    ),
                  ),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF4A00E0),
                    ),
                    strokeWidth: 3,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: isLandscape ? screenSize.height * 0.4 : 200.h,
              decoration: BoxDecoration(
                color: themeProvider.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(borderRadius?.r ?? 15.r),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: themeProvider.tertiaryTextColor,
                      size: 48.sp,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        color: themeProvider.tertiaryTextColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AdaptiveImageWidget extends StatelessWidget {
  final String imageUrl;
  final ThemeProvider themeProvider;
  final double? borderRadius;
  final bool enableZoom;

  const AdaptiveImageWidget({
    super.key,
    required this.imageUrl,
    required this.themeProvider,
    this.borderRadius,
    this.enableZoom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enableZoom 
          ? () => _showFullScreenImage(context)
          : null,
      child: OrientationBuilder(
        builder: (context, orientation) {
          return FullViewImageWidget(
            imageUrl: imageUrl,
            themeProvider: themeProvider,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

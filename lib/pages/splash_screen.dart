import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:ui' as ui;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<SlideData> _slides = [
    SlideData(
      title: 'الجهد الآمن',
      subtitle: 'لأعمال السباكة والكهرباء',
      description: 'نلتزم بتقديم خدمات هندسية عالية الجودة عبر كوادر متخصصة واتباع أفضل الممارسات والمعايير الدولية',
      icon: Icons.electrical_services,
      iconLabel: 'كهرباء',
      gradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    SlideData(
      title: 'الخبرة الميدانية',
      subtitle: 'سجل حافل من المشاريع المنجزة',
      description: 'خبرة متراكمة وسجل حافل من المشاريع المنجزة بكفاءة وجودة عالية عبر مختلف القطاعات',
      icon: Icons.engineering,
      iconLabel: 'هندسة',
      gradient: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    ),
    SlideData(
      title: 'الخيار الأول',
      subtitle: 'في المنطقة الشرقية',
      description: 'أن نكون الخيار الأول في المنطقة الشرقية والمملكة ككل في تقديم حلول كهربائية وميكانيكية متكاملة',
      icon: Icons.plumbing,
      iconLabel: 'سباكة',
      gradient: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // PageView للسلايدات
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return _buildSlide(_slides[index]);
              },
            ),
            
            // نقاط التنقل
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: _buildPageIndicator(),
            ),
            
            // زر التخطي
            Positioned(
              top: 50,
              right: 20,
              child: _buildSkipButton(),
            ),
            
            // زر التالي
            Positioned(
              bottom: 50,
              right: 20,
              child: _buildNextButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(SlideData slide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: slide.gradient,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // الجزء العلوي مع الشعار
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الشعار
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // أيقونة الخدمة
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        slide.icon,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // عنوان الخدمة
                    Text(
                      slide.iconLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // الجزء السفلي مع النص
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    // العنوان الرئيسي
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // العنوان الفرعي
                    Text(
                      slide.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // الوصف
                    Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // حقوق النشر
                    const Text(
                      '© 2024 الجهد الآمن - جميع الحقوق محفوظة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacementNamed(context, '/auth');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Text(
          'تخطي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        if (_currentPage < _slides.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          _currentPage < _slides.length - 1 ? Icons.arrow_forward : Icons.check,
          color: _slides[_currentPage].gradient[0],
          size: 24,
        ),
      ),
    );
  }
}

class SlideData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String iconLabel;
  final List<Color> gradient;

  SlideData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.iconLabel,
    required this.gradient,
  });
} 
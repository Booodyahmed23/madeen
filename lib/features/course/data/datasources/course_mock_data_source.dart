import 'course_data_source.dart';
import '../models/course_enrollment_model.dart';
import '../models/course_model.dart';
import '../models/course_section_model.dart';
import '../models/lesson_model.dart';

/// Local sample data — used only because the real Course API does not
/// exist yet (see COURSE_API_REQUIREMENTS.md). This is a UI-development
/// aid, **not** production content, selected automatically when
/// `AppConfig.isCourseApiAvailable` is `false` (the default) — see
/// course_data_source.dart. `videoAssetId`/`thumbnailAssetId` are opaque
/// placeholders only — **no real video or image exists for this mock
/// content**.
///
/// Course content is bilingual (English/Arabic, picked by the caller's
/// `languageCode`) — matching `docs/ARCHITECTURE.md` §19's `_i18n`
/// convention for *authored* content, unlike `AiTutorMockProvider`'s own
/// per-request-generated copy. Holds mutable, instance-level
/// [CourseEnrollment] state per course (lazily created — see that
/// entity's own doc comment) — same "one instance for the app's lifetime"
/// pattern `NotificationsMockDataSource` uses for its own mutable state.
class CourseMockDataSource implements CourseDataSource {
  static const _artificialDelay = Duration(milliseconds: 400);

  final Map<String, CourseEnrollmentModel> _enrollments = {};

  static final List<CourseModel> _coursesEn = [
    CourseModel(
      id: 'course-cma-part-1',
      title: 'CMA Part 1 Video Course',
      description:
          'A structured video walkthrough of Financial Planning, '
          'Performance, and Analytics — paired with this app\'s own '
          'Study Session and Exam Simulation practice.',
      sections: [
        CourseSectionModel(
          id: 'section-budgeting',
          courseId: 'course-cma-part-1',
          title: 'Budgeting and Forecasting',
          order: 0,
          lessons: [
            LessonModel(
              id: 'lesson-intro-budgeting',
              sectionId: 'section-budgeting',
              title: 'Introduction to Budgeting',
              description:
                  'Why budgets exist, the master budget, and how this '
                  'course connects to the Budgeting topics in Curriculum.',
              durationSeconds: 540,
              order: 0,
              videoAssetId: 'video-placeholder-1',
            ),
            LessonModel(
              id: 'lesson-flexible-budgets',
              sectionId: 'section-budgeting',
              title: 'Flexible Budgets and Variance Analysis',
              description:
                  'Building a flexible budget and interpreting the '
                  'variances it produces against actual results.',
              durationSeconds: 720,
              order: 1,
              videoAssetId: 'video-placeholder-2',
            ),
          ],
        ),
        CourseSectionModel(
          id: 'section-cost-management',
          courseId: 'course-cma-part-1',
          title: 'Cost Management',
          order: 1,
          lessons: [
            LessonModel(
              id: 'lesson-cost-behavior',
              sectionId: 'section-cost-management',
              title: 'Cost Behavior and Cost-Volume-Profit Analysis',
              description:
                  'Fixed vs. variable costs, and using CVP analysis to '
                  'find the break-even point.',
              durationSeconds: 660,
              order: 0,
              videoAssetId: 'video-placeholder-3',
            ),
            LessonModel(
              id: 'lesson-standard-costing',
              sectionId: 'section-cost-management',
              title: 'Standard Costing',
              description:
                  'Price and quantity variances, and how standard '
                  'costing differs from actual costing.',
              durationSeconds: 600,
              order: 1,
              videoAssetId: 'video-placeholder-4',
            ),
          ],
        ),
      ],
    ),
    CourseModel(
      id: 'course-cma-part-2',
      title: 'CMA Part 2 Video Course',
      description:
          'A structured video walkthrough of Strategic Financial '
          'Management — corporate finance and decision analysis.',
      sections: [
        CourseSectionModel(
          id: 'section-corporate-finance',
          courseId: 'course-cma-part-2',
          title: 'Corporate Finance',
          order: 0,
          lessons: [
            LessonModel(
              id: 'lesson-risk-return',
              sectionId: 'section-corporate-finance',
              title: 'Risk and Return',
              description:
                  'How risk and expected return relate, and why it '
                  'matters for a company\'s financing decisions.',
              durationSeconds: 600,
              order: 0,
              videoAssetId: 'video-placeholder-5',
            ),
          ],
        ),
        CourseSectionModel(
          id: 'section-decision-analysis',
          courseId: 'course-cma-part-2',
          title: 'Decision Analysis',
          order: 1,
          lessons: [
            LessonModel(
              id: 'lesson-relevant-costs',
              sectionId: 'section-decision-analysis',
              title: 'Relevant Costs for Decision-Making',
              description:
                  'Separating relevant from irrelevant costs when '
                  'evaluating a business decision.',
              durationSeconds: 540,
              order: 0,
              videoAssetId: 'video-placeholder-6',
            ),
          ],
        ),
      ],
    ),
  ];

  static final List<CourseModel> _coursesAr = [
    CourseModel(
      id: 'course-cma-part-1',
      title: 'الدورة المرئية لاختبار CMA الجزء الأول',
      description:
          'شرح مرئي منظم لموضوعات التخطيط المالي والأداء والتحليلات، '
          'يكمّل تمارين جلسات المذاكرة ومحاكاة الاختبار في هذا التطبيق.',
      sections: [
        CourseSectionModel(
          id: 'section-budgeting',
          courseId: 'course-cma-part-1',
          title: 'الموازنات والتنبؤ المالي',
          order: 0,
          lessons: [
            LessonModel(
              id: 'lesson-intro-budgeting',
              sectionId: 'section-budgeting',
              title: 'مقدمة في الموازنات',
              description:
                  'لماذا توجد الموازنات، والموازنة الرئيسية، وصلة هذه '
                  'الدورة بموضوعات الموازنات في المنهج الدراسي.',
              durationSeconds: 540,
              order: 0,
              videoAssetId: 'video-placeholder-1',
            ),
            LessonModel(
              id: 'lesson-flexible-budgets',
              sectionId: 'section-budgeting',
              title: 'الموازنات المرنة وتحليل الانحرافات',
              description:
                  'بناء موازنة مرنة وتفسير الانحرافات التي تنتجها مقارنة '
                  'بالنتائج الفعلية.',
              durationSeconds: 720,
              order: 1,
              videoAssetId: 'video-placeholder-2',
            ),
          ],
        ),
        CourseSectionModel(
          id: 'section-cost-management',
          courseId: 'course-cma-part-1',
          title: 'إدارة التكاليف',
          order: 1,
          lessons: [
            LessonModel(
              id: 'lesson-cost-behavior',
              sectionId: 'section-cost-management',
              title: 'سلوك التكاليف وتحليل التكلفة-الحجم-الربح',
              description:
                  'التكاليف الثابتة مقابل المتغيرة، واستخدام تحليل '
                  'التكلفة-الحجم-الربح لتحديد نقطة التعادل.',
              durationSeconds: 660,
              order: 0,
              videoAssetId: 'video-placeholder-3',
            ),
            LessonModel(
              id: 'lesson-standard-costing',
              sectionId: 'section-cost-management',
              title: 'التكلفة المعيارية',
              description:
                  'انحرافات السعر والكمية، وكيف تختلف التكلفة المعيارية '
                  'عن التكلفة الفعلية.',
              durationSeconds: 600,
              order: 1,
              videoAssetId: 'video-placeholder-4',
            ),
          ],
        ),
      ],
    ),
    CourseModel(
      id: 'course-cma-part-2',
      title: 'الدورة المرئية لاختبار CMA الجزء الثاني',
      description:
          'شرح مرئي منظم للإدارة المالية الاستراتيجية — التمويل '
          'المؤسسي وتحليل القرارات.',
      sections: [
        CourseSectionModel(
          id: 'section-corporate-finance',
          courseId: 'course-cma-part-2',
          title: 'التمويل المؤسسي',
          order: 0,
          lessons: [
            LessonModel(
              id: 'lesson-risk-return',
              sectionId: 'section-corporate-finance',
              title: 'المخاطر والعائد',
              description:
                  'كيف ترتبط المخاطر بالعائد المتوقع، وأهمية ذلك في '
                  'قرارات تمويل الشركة.',
              durationSeconds: 600,
              order: 0,
              videoAssetId: 'video-placeholder-5',
            ),
          ],
        ),
        CourseSectionModel(
          id: 'section-decision-analysis',
          courseId: 'course-cma-part-2',
          title: 'تحليل القرارات',
          order: 1,
          lessons: [
            LessonModel(
              id: 'lesson-relevant-costs',
              sectionId: 'section-decision-analysis',
              title: 'التكاليف ذات الصلة لاتخاذ القرار',
              description:
                  'الفصل بين التكاليف ذات الصلة وغير ذات الصلة عند '
                  'تقييم قرار عملي.',
              durationSeconds: 540,
              order: 0,
              videoAssetId: 'video-placeholder-6',
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Future<List<CourseModel>> getCourses(String languageCode) async {
    await Future<void>.delayed(_artificialDelay);
    return languageCode == 'ar' ? _coursesAr : _coursesEn;
  }

  @override
  Future<CourseEnrollmentModel> getEnrollment(String courseId) async {
    await Future<void>.delayed(_artificialDelay);
    return _enrollments[courseId] ??= CourseEnrollmentModel(courseId: courseId);
  }

  @override
  Future<CourseEnrollmentModel> setLessonCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final current = _enrollments[courseId] ??= CourseEnrollmentModel(
      courseId: courseId,
    );
    final updatedIds = Set<String>.from(current.completedLessonIds);
    if (completed) {
      updatedIds.add(lessonId);
    } else {
      updatedIds.remove(lessonId);
    }
    final updated = CourseEnrollmentModel(
      courseId: courseId,
      completedLessonIds: updatedIds,
      lastAccessedLessonId: current.lastAccessedLessonId,
    );
    _enrollments[courseId] = updated;
    return updated;
  }

  @override
  Future<CourseEnrollmentModel> setLastAccessedLesson({
    required String courseId,
    required String lessonId,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final current = _enrollments[courseId] ??= CourseEnrollmentModel(
      courseId: courseId,
    );
    final updated = CourseEnrollmentModel(
      courseId: courseId,
      completedLessonIds: current.completedLessonIds,
      lastAccessedLessonId: lessonId,
    );
    _enrollments[courseId] = updated;
    return updated;
  }
}

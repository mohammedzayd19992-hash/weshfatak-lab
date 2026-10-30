package com.uninews.uninews

import org.junit.Assert.*
import org.junit.Test

class AlertRulesTest {
    @Test fun studentsReceiveGeneralAndStudentNewsButNotStaffOnlyNews() {
        assertTrue(AlertRules.matches(emptySet(), setOf("Academic"), setOf("Students"), emptySet(), true))
        assertTrue(AlertRules.matches(setOf("Students"), setOf("Exams"), setOf("Students"), emptySet(), true))
        assertFalse(AlertRules.matches(setOf("Teaching Staff"), setOf("Academic"), setOf("Students"), emptySet(), true))
    }
    @Test fun categoryAndAudienceSelectionsBothApply() {
        assertFalse(AlertRules.matches(setOf("Students"), setOf("Academic"), setOf("Students"), setOf("Exams"), false))
        assertTrue(AlertRules.matches(setOf("Students"), setOf("Exams"), setOf("Students"), setOf("Exams"), true))
    }
    @Test fun importantModeExcludesActivitiesAndUncategorisedNews() {
        assertFalse(AlertRules.matches(emptySet(), setOf("Activities"), emptySet(), emptySet(), true))
        assertFalse(AlertRules.matches(emptySet(), emptySet(), emptySet(), emptySet(), true))
        assertTrue(AlertRules.matches(emptySet(), setOf("Activities"), emptySet(), emptySet(), false))
    }
}

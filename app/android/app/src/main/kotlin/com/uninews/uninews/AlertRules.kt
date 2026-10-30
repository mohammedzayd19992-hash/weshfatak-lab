package com.uninews.uninews

object AlertRules {
    fun matches(audiences: Set<String>, categories: Set<String>,
                selectedAudiences: Set<String>, selectedCategories: Set<String>,
                importantOnly: Boolean): Boolean =
        (selectedAudiences.isEmpty() || audiences.isEmpty() || audiences.any { it in selectedAudiences }) &&
        (selectedCategories.isEmpty() || categories.any { it in selectedCategories }) &&
        (!importantOnly || categories.any { it in setOf("Academic", "Exams", "Administrative") })
}

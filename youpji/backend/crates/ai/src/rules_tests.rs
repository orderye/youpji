#[allow(deprecated)]
use crate::parse_natural;
use crate::rules::RuleParser;

#[test]
fn parse_anshun_two_days_from_guiyang() {
    let req = RuleParser::new()
        .parse("从贵阳出发，去安顺玩两天，两个人，自驾，预算3000，喜欢自然景观")
        .unwrap();
    assert_eq!(req.origin, "贵阳");
    assert_eq!(req.destination, "安顺");
    assert_eq!(req.days, Some(2));
    assert_eq!(req.people, 2);
    assert_eq!(req.budget, 3000);
    assert_eq!(req.transport, "self_drive");
    assert!(req.interests.contains(&"nature".to_string()));
}

#[test]
fn parse_huangguoshu_maps_to_anshun() {
    let req = RuleParser::new().parse("黄果树两日游").unwrap();
    assert_eq!(req.destination, "安顺");
    assert_eq!(req.days, Some(2));
}

#[test]
fn parse_museum_destination_and_interests() {
    let req = RuleParser::new()
        .parse("想去贵州省博物馆和地质博物馆玩一天，自驾，看文博展览")
        .unwrap();
    assert_eq!(req.destination, "贵阳");
    assert_eq!(req.days, Some(1));
    assert!(req.interests.contains(&"museum".to_string()));
    assert!(req.interests.contains(&"history".to_string()));
}

#[test]
fn parse_low_intensity_for_elderly() {
    let req = RuleParser::new()
        .parse("带老人去安顺玩两天，少走路")
        .unwrap();
    assert_eq!(req.intensity, "low");
}

#[test]
fn invalid_budget_zero_or_negative_parses_through() {
    assert_eq!(
        RuleParser::new().parse("安顺两日游预算0").unwrap().budget,
        0
    );
    assert_eq!(
        RuleParser::new()
            .parse("安顺两日游预算-100")
            .unwrap()
            .budget,
        -100
    );
}

#[test]
fn invalid_explicit_date_errors() {
    assert!(RuleParser::new().parse("10月40日去安顺").is_err());
    assert!(RuleParser::new().parse("2026-02-30去安顺").is_err());
}

#[test]
fn empty_text_errors() {
    assert!(RuleParser::new().parse("   ").is_err());
}

#[test]
fn parse_per_person_budget_multiplies_by_people() {
    let req = RuleParser::new()
        .parse("两人去安顺玩两天，人均500，自驾")
        .unwrap();
    assert_eq!(req.people, 2);
    assert_eq!(req.budget, 1000);

    let req3 = RuleParser::new()
        .parse("3人去安顺玩两天，每人600")
        .unwrap();
    assert_eq!(req3.people, 3);
    assert_eq!(req3.budget, 1800);
}

#[test]
fn legacy_parse_still_works_via_alias() {
    // 兼容旧调用：parse_natural 只是 RuleParser 的别名（已废弃）
    #[allow(deprecated)]
    let req = parse_natural("从贵阳出发安顺两日游");
    assert_eq!(req.destination, "安顺");
}

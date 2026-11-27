package com.guoguanla;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.guoguanla.common.util.JsonHelper;
import com.guoguanla.module.bank.entity.EduQuestion;
import com.guoguanla.module.bank.mapper.EduQuestionMapper;
import com.guoguanla.module.system.QuestionDiagramBackfillRunner;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class Task20261128StudioDiagramTests {

    @Autowired
    private EduQuestionMapper questionMapper;

    @Autowired
    private QuestionDiagramBackfillRunner diagramBackfillRunner;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void studioDiagramQuestionsShouldBeSeededIdempotentlyWithValidStudioState() throws Exception {
        List<EduQuestion> studioQuestions = questionMapper.selectList(
                new LambdaQueryWrapper<EduQuestion>()
                        .like(EduQuestion::getTagsJson, "STUDIO_DIAGRAM")
                        .eq(EduQuestion::getEnabled, 1)
        );
        assertEquals(20, studioQuestions.size(), "Should seed all 20 JSXGraph Studio diagram questions");

        for (EduQuestion q : studioQuestions) {
            assertNotNull(q.getExtJson(), "Studio diagram question must have extJson");
            JsonNode ext = JsonHelper.readTree(objectMapper, q.getExtJson());
            assertNotNull(ext, "extJson must parse cleanly");
            JsonNode diagram = ext.path("diagram");
            assertTrue(diagram.path("primitives").isArray() && diagram.path("primitives").size() > 0,
                    "Diagram must have compiled primitives for " + q.getStem());
            JsonNode studioState = diagram.path("studioState");
            assertTrue(studioState.isObject() && studioState.path("bounds").isArray()
                            && studioState.path("bounds").size() == 4,
                    "Diagram must embed valid JSXGraph studioState for " + q.getStem());
        }

        // Re-running runner must remain strictly idempotent (still exactly 20, zero duplicates)
        diagramBackfillRunner.run(new DefaultApplicationArguments());
        long countAfter = questionMapper.selectCount(
                new LambdaQueryWrapper<EduQuestion>()
                        .like(EduQuestion::getTagsJson, "STUDIO_DIAGRAM")
                        .eq(EduQuestion::getEnabled, 1)
        );
        assertEquals(20L, countAfter, "Re-running QuestionDiagramBackfillRunner must not duplicate Studio questions");
    }
}

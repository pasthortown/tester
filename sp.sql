USE [MAXPOINT_V3.0]
GO
/****** Object:  StoredProcedure [config].[PREGUNTA_SUGERIDA_IAE_respuestas]    Script Date: 20/1/2021 21:48:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [config].[PREGUNTA_SUGERIDA_IAE_respuestas] 
	(@IDPregunta	VARCHAR(40)
	,@respuestas	VARCHAR(MAX)
	,@nivel			INT
	,@IDUsuario		NVARCHAR(40) = NULL) 
AS BEGIN
	SET NOCOUNT ON;

	IF(@IDUsuario = '') BEGIN
		SELECT 'ERROR' AS estado,'NO SE ENVIO EL ID DE USUARIO, NO SE REALIZA LA OPERACION' AS mensaje
		RETURN
	END
	
	DECLARE @continuar INT = 0
			,@IDStatusPreguntaSugeridaActivo	VARCHAR(40)
			,@IDStatusPreguntaSugeridaInactivo	VARCHAR(40)
			,@orden								INT = 0
			,@IDProducto						INT = 0
			,@descripcion						VARCHAR(100);
	insert into dbo.RespuestasEliminada
	select * 
	from Respuestas
	 WHERE IDPreguntaSugerida = @IDPregunta;

	--DELETE dbo.Respuestas WHERE IDPreguntaSugerida = @IDPregunta;
	--Preguntas Sugeridas
	WHILE (@continuar < 1) BEGIN
		IF(CHARINDEX('_', @respuestas) > 0) BEGIN

			SET @IDProducto = CAST(SUBSTRING(@respuestas, 0, CHARINDEX('_', @respuestas)) AS INT);
			SET @respuestas = SUBSTRING(@respuestas, CHARINDEX('_', @respuestas)+1, LEN(@respuestas));
			SET @descripcion = SUBSTRING(@respuestas, 0, CHARINDEX('_', @respuestas));
			SET @respuestas = SUBSTRING(@respuestas, CHARINDEX('_', @respuestas)+1, LEN(@respuestas));
			SET @orden = CAST(SUBSTRING(@respuestas, 0, CHARINDEX('_', @respuestas)) AS INT);
			SET @respuestas = SUBSTRING(@respuestas, CHARINDEX('_', @respuestas)+1, LEN(@respuestas));

			IF not EXISTS (select * from dbo.Respuestas WHERE IDPreguntaSugerida = @IDPregunta and plu_id =@IDProducto ) 
				BEGIN

					INSERT INTO dbo.Respuestas
							( IDPreguntaSugerida ,
								plu_id ,
								res_descripcion ,
								orden ,
								nivel,
								lastUser,
								lastUpdate,
								IDRespuestasPadre)
					VALUES  ( @IDPregunta , -- IDPreguntaSugerida - uniqueidentifier
								@IDProducto , -- plu_id - bigint
								@descripcion , -- res_descripcion - varchar(200)
								@orden , -- orden - int
								@nivel,
								@IDUsuario,
								GETDATE(), null);

				END

		END ELSE BEGIN
			SET @continuar = 1;
		END
	END
	

END